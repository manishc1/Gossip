
-module(spawner).

-compile([nowarn_unused_function , nowarn_unused_vars]).

-export([start/0 , start/1 , process/2 , findMax/0 , calculateMax/0 , findMin/0 , calculateMin/0 , findAvg/0 , calculateAvg/0 , findFineAvg/0 , calculateFineAvg/0 , updateFragment/2 , calculateUpdate/2 , retrieveFragment/1 , calculateRetrieve/1 , findMedian/0 , calculateMedian/0 , collectDeadProcesses/0]).


%% ---------- Definitions ----------

%% # of processes
-define(LIMIT , 8000).

%% # of Fragments
-define(FRAGLIMIT , trunc(?LIMIT/2)).

%% # of Steps
-define(STEPS , trunc(2*math:log(?LIMIT)/math:log(2))).

%% Timeout of receive 
-define(TIMEOUT , 1000).

%% Interval for each Gossip Iteration
-define(INTERVAL , 100).


%% ---------- Derive Fragment Value List and Id List ----------

getFragValueList([]) ->
	N=[],
	N;

getFragValueList([E | L]) ->
	{_ , Value} = E,
	lists:append(Value , getFragValueList(L)).

getFragIdList([]) ->
	N=[],
	N;

getFragIdList([E | L]) ->
	{Id , _} = E,
	[Id | getFragIdList(L)].


%% ---------- Selection of Neighbor ----------

selectNeighbor() ->
	MyNeighbors = getMirrorChordNeighborList(get('number')) , %%get('neighborList'),
	random:seed(now()),
	Index = random:uniform(2*(length(MyNeighbors))),
	case (Index rem 2) of
		0 ->
			Neighbor = lists:nth(trunc(Index/2) , MyNeighbors),
			IsPresent = lists:member(Neighbor , registered()),
			if
				IsPresent == (false) ->
			  		selectNeighbor();
				true ->
					Neighbor
			end;
	     	1 ->
			get('name')
	end.


%% ---------- List of Operations in Secret ----------

getOperationList([]) ->
	L = [],
	L;

getOperationList([Secret | RemainingSecretList]) ->
	Operation = element(1 , Secret),
	[Operation | getOperationList(RemainingSecretList)].


%% ---------- Find Max of Two ----------

findMax2(X , Y) ->
	if
		X > Y ->
		        Max = X;
		true ->
			Max = Y
	end,
	Max.


findMyMax(0 , L , Max) ->
	Max;

findMyMax(N , L , Max) ->
	Nth = lists:nth(N , L),
        findMyMax(N-1 , L , findMax2(Max , Nth)).


%% ---------- Max Operation for Update ----------

doMaxUpdate(Secret) ->

	{_ , HisMax} = Secret,

	Operation = element(1 , Secret),

	case lists:member(Operation , getOperationList(get('secret'))) of

	        false ->
			MyFragValueList = getFragValueList(get('fragment')),
			MyMax = findMyMax(length(MyFragValueList) , MyFragValueList , lists:nth(1 , MyFragValueList)),
			Max = findMax2(HisMax , MyMax),
			put(secret , ([{max , Max} | get('secret')]));
		true ->
			{_ , {_ , MyMax}} = lists:keysearch(max , 1 , get('secret')),
			Max = findMax2(HisMax , MyMax),
			put(secret , [{max , Max} | lists:keydelete(max , 1 , get('secret'))])
	end.
	%%io:format("Max | ~p | | ~p |~n",[get('name') , Max]).


%% ---------- Find Min of Two ----------

findMin2(X , Y) ->
	if
		X > Y ->
		        Min = Y;
		true ->
			Min = X
	end,
	Min.


findMyMin(0 , L , Min) ->
	Min;

findMyMin(N , L , Min) ->
	Nth = lists:nth(N , L),
        findMyMin(N-1 , L , findMin2(Min , Nth)).


doMinUpdate(Secret) ->

	{_ , HisMin} = Secret,

	Operation = element(1 , Secret),

	case lists:member(Operation , getOperationList(get('secret'))) of

	        false ->
			MyFragValueList = getFragValueList(get('fragment')),
			MyMin = findMyMin(length(MyFragValueList) , MyFragValueList , lists:nth(1 , MyFragValueList)),
			Min = findMin2(HisMin , MyMin),
			put(secret , ([{min , Min} | get('secret')]));
		true ->
			{_ , {_ , MyMin}} = lists:keysearch(min , 1 , get('secret')),
			Min = findMin2(HisMin , MyMin),
			put(secret , [{min , Min} | lists:keydelete(min , 1 , get('secret'))])
	end.
	%%io:format("Min | ~p | | ~p |~n",[get('name') , Min]).


%% ---------- Find Avg of Two ----------

findAvg2(X , Xlen , Y , Ylen) ->
	((X * Xlen) + (Y * Ylen)) / (Xlen + Ylen).


doAvgUpdate(Secret) ->

	{_ , HisAvg , HisLen} = Secret,

	Operation = element(1 , Secret),

	case lists:member(Operation , getOperationList(get('secret'))) of

	        false ->
			MyFragValueList = getFragValueList(get('fragment')),
			MyAvg = (lists:foldl(fun(X, Sum) -> X + Sum end, 0, MyFragValueList)) / length(MyFragValueList),
			MyLen = length(MyFragValueList),
			Avg = findAvg2(HisAvg , HisLen , MyAvg , MyLen),
			put(secret , ([{avg , Avg , MyLen} | get('secret')]));
		true ->
			{_ , {_ , MyAvg , MyLen}} = lists:keysearch(avg , 1 , get('secret')),
			Avg = findAvg2(HisAvg , HisLen , MyAvg , MyLen),
			put(secret , [{avg , Avg , MyLen} | lists:keydelete(avg , 1 , get('secret'))])
	end.
	%%io:format("Avg | ~p | | ~p , ~p |~n",[get('name') , Avg , MyLen]).


getFragSumLenList([]) ->
	L = [],
	L;
getFragSumLenList([Frag | FragList]) ->
	{Id , Value} = Frag,
	[{Id , lists:sum(Value) , length(Value)} | getFragSumLenList(FragList)].


getSeenFragSum([]) ->
	0;

getSeenFragSum([SeenFrag | SeenFragList]) ->
	{_ , Sum , _} = SeenFrag,
	Sum + getSeenFragSum(SeenFragList).


getSeenFragLen([]) ->
	0;

getSeenFragLen([SeenFrag | SeenFragList]) ->
	{_ , _ , Len} = SeenFrag,
	Len + getSeenFragLen(SeenFragList).

mergeSeenFrags(HisSeenFrags , []) ->
	HisSeenFrags;

mergeSeenFrags(HisSeenFrags , [Frag | MySeenFrags]) ->
	case lists:member(Frag , HisSeenFrags) of
	     	false ->
			[Frag | mergeSeenFrags(HisSeenFrags , MySeenFrags)];
		true ->
			mergeSeenFrags(HisSeenFrags , MySeenFrags)
	end.


doFineAvgUpdate(Secret) ->

	{_ , HisAvg , HisSeenFrags} = Secret,

	Operation = element(1 , Secret),

	case lists:member(Operation , getOperationList(get('secret'))) of

	        false ->
			MySeenFrags = getFragSumLenList(get('fragment')),
			SeenFrags = mergeSeenFrags(HisSeenFrags , MySeenFrags),
			MyLen = getSeenFragLen(SeenFrags),
			MyAvg = getSeenFragSum(SeenFrags) / MyLen,
			put(secret , ([{fine_avg , MyAvg , SeenFrags} | get('secret')]));
		true ->
			{_ , {_ , _ , MySeenFrags}} = lists:keysearch(avg , 1 , get('secret')),
			SeenFrags = mergeSeenFrags(HisSeenFrags , MySeenFrags),
			MyLen = getSeenFragLen(SeenFrags),
			MyAvg = getSeenFragSum(SeenFrags) / MyLen,
			put(secret , ([{fine_avg , MyAvg , SeenFrags} | lists:keydelete(avg , 1 , get('secret'))]))
	end.
	%%io:format("Avg | ~p | | ~p |~n",[get('name') , MyAvg]).


%% ---------- Fragment Update ----------

doUpdateFragUpdate(Secret) ->

        case lists:member(Secret , get('secret')) of

	        false ->
			{_ , HisId , HisValue} = Secret,
			MyFragIdList = getFragIdList(get('fragment')),
			IsPresent = lists:member(HisId , MyFragIdList),			
	 		if
			        IsPresent == (true) ->
					NewFragment = [{HisId , HisValue} | lists:keydelete(HisId , 1 , get('fragment'))],
					put(fragment , (NewFragment));
				true ->
		      		     io:format("")
	 		end,
			put(secret , ([Secret | get('secret')]));
		true ->
			io:format("")
	end.
	%%io:format("UpF | ~p | | ~p |~n", [get('name') , get('fragment')]).


%% ---------- Fragment Retrieval ----------

doRetrieveFragUpdate(Secret) ->

	{_ , HisFragId , HisFragValue} = Secret,

	MyFragIdList = getFragIdList(get('fragment')),

	IdPresent = lists:member(HisFragId , MyFragIdList),
	IsPresent = getMatch(Secret , get('secret')),

	case  IsPresent of

	        false ->
			if
				IdPresent == (true) ->
					{_ , {_ , MyFragValue}} = lists:keysearch(HisFragId , 1 , get('fragment')),
					put(secret , ([{retrieve_frag , HisFragId , MyFragValue} | get('secret')]));
				true ->
					put(secret , ([Secret | get('secret')]))
			end;
		_ ->
			if
				IdPresent == (true) ->
					{_ , {_ , MyFragValue}} = lists:keysearch(HisFragId , 1 , get('fragment')),
					put(secret , ([{retrieve_frag , HisFragId , MyFragValue} | lists:filter(fun(X) -> X /= (IsPresent) end, get('secret'))]));
				true ->
				        if
						length(HisFragValue) /=0 ->
							put(secret , ([Secret | lists:filter(fun(X) -> X /= (IsPresent) end, get('secret'))]));
					true ->
						true
					end
			end
	end.
	%%io:format("ReF | ~p | | ~p |~n",[get('name') , get('secret')]).


%% ---------- Find Median ----------

findMedian(List) ->

	SortedList = lists:sort(List),

	Length = length(SortedList),

	case (Length rem 2) of

	        0 ->
		        Med1 = trunc(Length / 2),
			Med2 = Med1 + 1,
			Median = (lists:nth(Med1 , SortedList) + lists:nth(Med2 , SortedList)) / 2;
		1 ->
			Med = trunc((Length + 1) / 2),
			Median = lists:nth(Med , SortedList)
	end,

	Median.


mergeFragLists(L , []) ->
	L;

mergeFragLists(L1 , [E | L2]) ->
	case lists:member(E , L1) of
	        false ->
		        L3 = [E | L1];
		true ->
			L3 = L1
	end,
	mergeFragLists(L3 , L2).


getValueList([] , ValueList) ->
	ValueList;
getValueList([E | L] , ValueList) ->
	{_ , Value} = E,
	NewValueList = lists:append(Value , ValueList),
	getValueList(L , NewValueList).


doMedianUpdate(Secret) ->

	{_ , _ , HisFragList} = Secret,

	Operation = element(1 , Secret),

	case lists:member(Operation , getOperationList(get('secret'))) of

	        false ->
			MyFragments = get('fragment'),
			MergedList = mergeFragLists(MyFragments , HisFragList),
			MergedValueList = getValueList(MergedList , []),
			MyMedian = findMedian(MergedValueList),
			put(secret , ([{median , MyMedian , MergedList} | get('secret')]));
		true ->
			{_ , {_ , _ , MyFragList}} = lists:keysearch(median , 1 , get('secret')),
			MergedList = mergeFragLists(MyFragList , HisFragList),
			MergedValueList = getValueList(MergedList , []),
			MyMedian = findMedian(MergedValueList),
			put(secret , [{median , MyMedian , MergedList} | lists:keydelete(median , 1 , get('secret'))])
	end.
	%%io:format("Median | ~p | | ~p |~n",[get('name') , MyMedian]).


%% ---------- Update Driver ----------

update([]) ->
	true;

update([Secret | RemainingSecret]) ->
	
        Operation = element(1,Secret),

	case Operation of
	        max ->
		        doMaxUpdate(Secret);
		min ->
		        doMinUpdate(Secret);
		avg ->
			doAvgUpdate(Secret);
		fine_avg ->
		        doFineAvgUpdate(Secret);
		update_frag ->
		        doUpdateFragUpdate(Secret);
		retrieve_frag ->
		        doRetrieveFragUpdate(Secret);
		median ->
		        doMedianUpdate(Secret);
		_ ->
		        io:format("")
	end,
		
	update(RemainingSecret).

		
%% ---------- Push ----------

waitPushResponse() ->
	receive

		{push_response , NeighborSecret} ->
		        update(NeighborSecret)

	after ?TIMEOUT ->
	      	io:format("")
	end.


push() ->
	Neighbor = selectNeighbor(),
	Name = get('name'),
	if
		Name /= Neighbor ->
			Secret = get('secret'),
			Neighbor ! {push_request , Secret , Name},
			waitPushResponse();
		true ->
			true
	end.


%% ---------- Pull ----------

waitPullComplete() ->
	receive

		{pull_complete , NeighborSecret} ->
			update(NeighborSecret)

	after ?TIMEOUT ->
	      	io:format("")

	end.


waitPullResponse() ->
	receive

		{pull_response , NeighborSecret , Neighbor} ->
			build(NeighborSecret),
			whereis(Neighbor) ! {pull_complete , get('secret')},
			update(NeighborSecret);

		 no_secret ->
			io:format("")

	after ?TIMEOUT ->
		io:format("")

	end.


pull() ->
	Neighbor = selectNeighbor(),
	Name = get('name'),
	if
		Neighbor /= Name ->
			 whereis(Neighbor) ! {pull_request , Name},
			 waitPullResponse();
		true ->
			 io:format("")
	end,
	io:format("").


%% ---------- Push And Pull Alternation ----------

pushpull() ->
	Phase = get('phase'),
	
	%%io:format("| ~p | Steps | ~p |~n",[get('name'),get('steps')]),
	Steps = get('steps'),
	case Steps > (0) of
	     	true ->
			put(steps , Steps - 1),
			put(print , (ok));
		_ ->
			true
	end,

	case (Steps == (0)) and (get('print') == (ok)) of
	     	true ->
			put(print , (no)),
			Avg = element(2 , lists:nth(1 , get('secret'))),
			io:format("| ~p | | ~p |~n",[get('name') , Avg]);
		_ ->
			true
	end,

	if
		Phase == (push) ->
		      	%%io:format("| ~p | in push~n",[get('name')]),
			Secret = get('secret'),
			if
				length(Secret) /= (0) ->
					case Steps < (0) of
					     	true ->
							put(steps , (?STEPS));
						_ ->
							true
					end,
					NewSteps = get('steps'),
					case NewSteps > 0 of
					     	true ->
							push();
						_ ->
							true
					end;
			true ->
				io:format("")
			end,
			put(phase , (pull));
		true ->
		      	%%io:format("| ~p | in pull~n",[get('name')]),
			NewSteps = get('steps'),
			case (NewSteps /= 0) of
			     	true ->
					pull();
				_ ->
					true
			end,
			put(phase , (push))
	end,
	%%io:format("| ~p | return from pull~n",[get('name')]).
	io:format("").


%% ---------- Build The Secret To Be Returned ----------

doMaxBuild(Secret) ->

	Operation = element(1 , Secret),

	case lists:member(Operation , getOperationList(get('secret'))) of

	        false ->
			MyFragValueList = getFragValueList(get('fragment')),
			MyMax = findMyMax(length(MyFragValueList) , MyFragValueList , lists:nth(1 , MyFragValueList)),
			put(secret , ([{max , MyMax} | get('secret')]));
		true ->
			true
	end.


doMinBuild(Secret) ->

	Operation = element(1 , Secret),

	case lists:member(Operation , getOperationList(get('secret'))) of

	        false ->
			MyFragValueList = getFragValueList(get('fragment')),
			MyMin = findMyMin(length(MyFragValueList) , MyFragValueList , lists:nth(1 , MyFragValueList)),
			put(secret , ([{min , MyMin} | get('secret')]));
		true ->
			true
	end.


doAvgBuild(Secret) ->

	Operation = element(1 , Secret),

	case lists:member(Operation , getOperationList(get('secret'))) of

	        false ->
			MyFragValueList = getFragValueList(get('fragment')),
			MyAvg = (lists:foldl(fun(X, Sum) -> X + Sum end, 0, MyFragValueList)) / length(MyFragValueList),
			MyLen = length(MyFragValueList),
			put(secret , ([{avg , MyAvg , MyLen} | get('secret')]));
		true ->
			true
	end.


doFineAvgBuild(Secret) ->

	Operation = element(1 , Secret),

	case lists:member(Operation , getOperationList(get('secret'))) of

	        false ->
			MyFragValueList = getFragValueList(get('fragment')),
			SeenFrags = getFragSumLenList(get('fragment')),
			MyLen = getSeenFragLen(SeenFrags),
			MyAvg = getSeenFragSum(SeenFrags) / MyLen,
			put(secret , ([{fine_avg , MyAvg , SeenFrags} | get('secret')]));
		true ->
			true
	end.


getMatch(_, []) ->
        false;

getMatch(Secret , [MySecret | MyRemainingSecret]) ->

	Operation = element(1 , MySecret),
	if
		Operation == (retrieve_frag) ->
			{HisSec , HisFragId , _} = Secret,
			{MySec , MyFragId , _} = MySecret,

        		case  ((HisSec == (MySec)) and (HisFragId == (MyFragId)))of
	        	      	true ->
					MySecret;
				false ->
					getMatch(Secret , MyRemainingSecret)
			end;
		true ->
			getMatch(Secret , MyRemainingSecret)
	end.


doRetrieveFragBuild(Secret) ->

	{_ , HisFragId , HisFragValue} = Secret,

	MyFragIdList = getFragIdList(get('fragment')),

	IdPresent = lists:member(HisFragId , MyFragIdList),

	IsPresent = getMatch(Secret , get('secret')),

	case  IsPresent of

	        false ->
			if
				IdPresent == (true) ->
					{_ , {_ , MyFragValue}} = lists:keysearch(HisFragId , 1 , get('fragment')),
					put(secret , ([{retrieve_frag , HisFragId , MyFragValue} | get('secret')]));
				true ->
					put(secret , ([Secret | get('secret')]))
			end;
		_ ->
			if
				IdPresent == (true) ->
					{_ , {_ , MyFragValue}} = lists:keysearch(HisFragId , 1 , get('fragment')),
					put(secret , ([{retrieve_frag , HisFragId , MyFragValue} | lists:filter(fun(X) -> X /= (IsPresent) end, get('secret'))]));
				true ->
				        if
						length(HisFragValue) /=0 ->
							put(secret , ([Secret | lists:filter(fun(X) -> X /= (IsPresent) end, get('secret'))]));
					true ->
						true
					end
			end
	end.


doMedianBuild(Secret) ->

	Operation = element(1 , Secret),

	case lists:member(Operation , getOperationList(get('secret'))) of

	        false ->
			MyMedian = findMedian(getFragValueList(get('fragment'))),
			put(secret , ( [ {median , MyMedian , get('fragment')} | get('secret') ] ) );
		true ->
			true;
		_ ->
			io:format("")
	end.


build([]) ->
	true;

build([Secret | RemainingSecret]) ->

        Operation = element(1,Secret),

	%%io:format("~p ~p ~p~n",[self() , Operation , get('secret')]),

	case Operation of
	        max ->
		        doMaxBuild(Secret);
		min ->
		        doMinBuild(Secret);
		avg ->
			doAvgBuild(Secret);
		fine_avg ->
		        doFineAvgBuild(Secret);
		retrieve_frag ->
			doRetrieveFragBuild(Secret);
		median ->
			doMedianBuild(Secret);
		_ ->
		        io:format("")
	end,
		
	build(RemainingSecret).


%% ---------- Listen And PushPull Alternation of Process ----------

listen() ->

	%%io:format("Secret | ~p | | ~p |~n",[get('name') , get('secret')]),
	pushpull(),

	receive

		{pull_request , Neighbor} ->
			%%io:format("| ~p | : pull request from | ~p | | ~p | ~p |~n",[get('name') , Neighbor , whereis(Neighbor) , registered()]),
			Secret = get('secret'),
			if
				length(Secret) == (0) ->
				       	whereis(Neighbor) ! no_secret,
					io:format("");
				true ->
					whereis(Neighbor) ! {pull_response , get('secret') , get('name')},
					waitPullComplete()
			end,
			listen();

		{push_request , NeighborSecret , Neighbor} ->
			build(NeighborSecret),
			Neighbor ! {push_response , get('secret')},
			update(NeighborSecret),
			listen();

		find_max ->
			MyFragValueList = getFragValueList(get('fragment')),
			NewSecret = [{max , findMyMax(length(MyFragValueList) , MyFragValueList , lists:nth(1 , MyFragValueList))} | get('secret')],
			put(secret , (NewSecret)),
			listen();

		find_min ->
			MyFragValueList = getFragValueList(get('fragment')),
			NewSecret = [{min , findMyMin(length(MyFragValueList) , MyFragValueList , lists:nth(1 , MyFragValueList))} | get('secret')],
			put(secret , (NewSecret)),
			listen();

		find_avg ->
			MyFragValueList = getFragValueList(get('fragment')),
			MyAvg = (lists:foldl(fun(X, Sum) -> X + Sum end, 0, MyFragValueList)) / length(MyFragValueList),
			MyLen = length(MyFragValueList),
			put(secret , ([{avg , MyAvg , MyLen} | get('secret')])),
			listen();

		find_fineavg ->
			MyFragValueList = getFragValueList(get('fragment')),
			SeenFrags = getFragSumLenList(get('fragment')),
			MyLen = getSeenFragLen(SeenFrags),
			MyAvg = getSeenFragSum(SeenFrags) / MyLen,
			put(secret , ([{fine_avg , MyAvg , SeenFrags} | get('secret')])),
			listen();

		{update_fragment , FragmentId , Value} ->
			MyFragIdList = getFragIdList(get('fragment')),
			IsPresent = lists:member(FragmentId , MyFragIdList),
			if
				IsPresent == (true) ->
					NewFragment = [{FragmentId , Value} | lists:keydelete(FragmentId , 1 , get('fragment'))],
					put(fragment , (NewFragment));
				true ->
					 io:format("")
			end,
			put(secret , ([{update_frag , FragmentId , Value} | get('secret')])),
			listen();

		{retrieve_fragment , FragmentId} ->
			MyFragIdList = getFragIdList(get('fragment')),
			IsPresent = lists:member(FragmentId , MyFragIdList),
			if
				IsPresent == (true) ->
					MyFragments = get('fragment'),
				        {_ , {MyFragId , MyFragValue}} = lists:keysearch(FragmentId , 1 , MyFragments),
					put(secret , ([{retrieve_frag , MyFragId , MyFragValue} | get('secret')]));
				true ->
					put(secret , ([{retrieve_frag , FragmentId , []} | get('secret')]))					
			end,
			listen();

		find_median ->
			NewSecret = [ {median , findMedian(getFragValueList(get('fragment'))) , get('fragment')} | get('secret')],
			put(secret , (NewSecret)),
			listen()

	after ?TIMEOUT ->
	      listen()

	end.


%% ---------- Initialize the Process Dictionary ----------

init_dict(MyNumber, NeighborList) ->

	put(number , (MyNumber)),
	put(name , (list_to_atom( string:concat("p" , integer_to_list(MyNumber))))),
	%%put(neighborList , (NeighborList)),
	put(secret , ([])),
	put(fragment , [{(MyNumber rem ?FRAGLIMIT) , [(MyNumber rem ?FRAGLIMIT) , ((MyNumber rem ?FRAGLIMIT) + ?FRAGLIMIT)]} , {((MyNumber rem ?FRAGLIMIT) + ?FRAGLIMIT) , [(MyNumber rem ?FRAGLIMIT) + ?LIMIT , ((MyNumber rem ?FRAGLIMIT) + ?FRAGLIMIT) + ?LIMIT]}]),
	put(phase , (push)),
	put(steps , (-1)),
	io:format("| ~p | | ~p | | ~p | | ~p | | ~p |~n",[get('number') , get('name') , get('neighborList') , get('secret') , get('fragment')]),
	io:format("").


%% ---------- Entry Point of Process ----------

process(MyNumber , NeighborList) ->

	init_dict(MyNumber , NeighborList),
	listen(),
	io:format("| ~p | I am exiting",[get('name')]).


%% ---------- Ring Topology ----------

getRingNeighborList(MyNumber) ->

	Me = list_to_atom( string:concat( "p" , integer_to_list( MyNumber ))),
	Predecessor = list_to_atom( string:concat( "p" , integer_to_list( ((?LIMIT + MyNumber - 1) rem ?LIMIT )))),
	Successor = list_to_atom( string:concat( "p" , integer_to_list( ((MyNumber + 1) rem ?LIMIT )))),

	NeighborList = [Me , Predecessor , Successor],
	NeighborList.


%% ---------- Chord Topology ----------

floor(X) ->
    T = erlang:trunc(X),
    case (X - T) of
        Neg when Neg < 0 -> T - 1;
        Pos when Pos > 0 -> T;
        _ -> T
    end.


ceiling(X) ->
        T = erlang:trunc(X),
	case (X - T) of
	        Neg when Neg < 0 -> T;
		Pos when Pos > 0 -> T + 1;
		_ -> T
	end.


log2(X) ->
	math:log(X) / math:log(2).


getList(MyNumber , List , 0) ->
	List;

getList(MyNumber , List , I) ->
	NewList = [list_to_atom( string:concat( "p" , integer_to_list( trunc((MyNumber + math:pow(2,I-1))) rem ?LIMIT ))) | List],
	getList(MyNumber , NewList , I-1).


getReverseList(MyNumber , List , 0) ->
	List;

getReverseList(MyNumber , List , I) ->
	NewList = [list_to_atom(string:concat("p" , integer_to_list(trunc((MyNumber - math:pow(2,I-1) + ?LIMIT)) rem ?LIMIT))) | List],
	getReverseList(MyNumber , NewList , I-1).


getMirrorChordNeighborList(MyNumber) ->

	Length = ceiling(log2(?LIMIT)/2),

	Me = list_to_atom( string:concat( "p" , integer_to_list( MyNumber ))),

	ChordList = getList(MyNumber , [] , Length),
	ReverseChordList = getReverseList(MyNumber , [] , Length),

	lists:umerge(lists:sort(ChordList) , lists:sort(ReverseChordList)).


getChordNeighborList(MyNumber) ->
	Length = ceiling(log2(?LIMIT)),

	Me = list_to_atom( string:concat( "p" , integer_to_list( MyNumber ))),
	T1 = [Me | getList(MyNumber , [] , Length)],

	Successor = list_to_atom( string:concat( "p" , integer_to_list( ((MyNumber + 1) rem ?LIMIT )))),
	IsSuccessor = lists:member(Successor , T1),
	if
		IsSuccessor == (false) ->
			T2 = [Successor | T1];
		true ->
			T2 = T1
	end,

	Predecessor = list_to_atom( string:concat( "p" , integer_to_list( ((?LIMIT + MyNumber - 1) rem ?LIMIT )))),
	IsPredecessor = lists:member(Predecessor , T2),
	if
		IsPredecessor == (false) ->
			T3 = [Predecessor | T2];
		true ->
			T3 = T2
	end,

	MirrorMyNumber = (?LIMIT - MyNumber - 1),
	MirrorMe = list_to_atom( string:concat( "p" , integer_to_list( MirrorMyNumber ))),
	IsMirrorMe = lists:member(MirrorMe , T3),
	if
		IsMirrorMe == (false) ->
			NeighborList = [MirrorMe | T3];
		true ->
			NeighborList = T3
	end,

	NeighborList.


%% ---------- Mirror Ring Topology ----------

getMirrorRingNeighborList(MyNumber) ->

	Me = list_to_atom( string:concat( "p" , integer_to_list( MyNumber ))),
	Predecessor = list_to_atom( string:concat( "p" , integer_to_list( ((?LIMIT + MyNumber - 1) rem ?LIMIT )))),
	Successor = list_to_atom( string:concat( "p" , integer_to_list( ((MyNumber + 1) rem ?LIMIT )))),
	T1 = [Me , Predecessor , Successor],

	MirrorMyNumber = (?LIMIT - MyNumber - 1),
	MirrorMe = list_to_atom( string:concat( "p" , integer_to_list( MirrorMyNumber ))),
	IsMirrorMe = lists:member(MirrorMe , T1),
	if
		IsMirrorMe == (false) ->
			T2 = [MirrorMe | T1];
		true ->
			T2 = T1
	end,

	MirrorSuccessor = list_to_atom( string:concat( "p" , integer_to_list( ((MirrorMyNumber + 1) rem ?LIMIT )))),
	IsMirrorSuccessor = lists:member(MirrorSuccessor , T2),
	if
		IsMirrorSuccessor == (false) ->
			T3 = [MirrorSuccessor | T2];
		true ->
			T3 = T2
	end,

	MirrorPredecessor = list_to_atom( string:concat( "p" , integer_to_list( ((?LIMIT + MirrorMyNumber - 1) rem ?LIMIT )))),
	IsMirrorPredecessor = lists:member(MirrorPredecessor , T3),
	if
		IsMirrorPredecessor == (false) ->
			NeighborList = [MirrorPredecessor | T3];
		true ->
			NeighborList = T3
	end,

	NeighborList.


%% ---------- Creation of Processes ----------

do_spawn(0) ->
	ok;

do_spawn(N) ->
    	ProcessName = list_to_atom( string:concat( "p" , integer_to_list( ?LIMIT - N ) ) ),
	process_flag(trap_exit, true),
	%%register(ProcessName , spawn_link(?MODULE , process , [(?LIMIT - N) , getRingNeighborList( ?LIMIT - N )])),
	%%register(ProcessName , spawn_link(?MODULE , process , [(?LIMIT - N) , getMirrorRingNeighborList( ?LIMIT - N )])),
	%%register(ProcessName , spawn_link(?MODULE , process , [(?LIMIT - N) , getChordNeighborList( ?LIMIT - N )])),
	register(ProcessName , spawn_link(?MODULE , process , [(?LIMIT - N) , getMirrorChordNeighborList( ?LIMIT - N )])),
	do_spawn(N-1).


%% ---------- Listsing Dead Processes ----------

checkIfDead(0 , List) ->
	List;

checkIfDead(N , List) ->
     	 ProcessName = list_to_atom( string:concat( "p" , integer_to_list( N ) ) ),
	 IsPresent = lists:member(ProcessName , registered()),
	 if
		IsPresent == (true) ->
			  NewList = checkIfDead(N-1 , List);
		true ->
			  NewList = [ProcessName | checkIfDead(N-1 , List)]
	 end,
	 NewList.


collectDeadProcesses() ->
	io:format("Dead | ~p |~n", [checkIfDead(?LIMIT-1 , [])]),
	timer:sleep(3000),
	collectDeadProcesses().


%% ---------- Entry Point ----------

start() ->
	do_spawn(?LIMIT),
	%%register(collector , spawn(?MODULE , collectDeadProcesses , [])),
	io:format("").

start(Operation) ->
	do_spawn(?LIMIT),
	case Operation of
		max ->
			findMax();
		min ->
			findMin();
		avg ->
			findAvg();
		fineavg ->
			findFineAvg();
		up ->
			updateFragment(0 , [10 , 20]);
		re ->
			retrieveFragment(0);
		median ->
			findMedian();
		_ ->
			io:format("wrong operation")
	end,
	%%register(collector , spawn(?MODULE , collectDeadProcesses , [])),
	io:format("").

%% ---------- Various Operations ----------

calculateMax() ->
	whereis(p0) ! find_max,
	exit(self() , "end of purpose").

findMax() ->
	spawn(?MODULE , calculateMax , []).


calculateMin() ->
	whereis(p0) ! find_min,
	exit(self() , "end of purpose").

findMin() ->
	spawn(?MODULE , calculateMin , []).


calculateAvg() ->
	whereis(p0) ! find_avg,
	exit(self() , "end of purpose").

findAvg() ->
	spawn(?MODULE , calculateAvg , []).


calculateFineAvg() ->
	whereis(p0) ! find_fineavg,
	exit(self() , "end of purpose").

findFineAvg() ->
	spawn(?MODULE , calculateFineAvg , []).


calculateUpdate(FragmentId , Value) ->
	whereis(p0) ! {update_fragment , FragmentId , Value},
	exit(self() , "end of purpose").

updateFragment(FragmentId , Value) ->
	spawn(?MODULE , calculateUpdate , [FragmentId , Value]).


calculateRetrieve(FragmentId) ->
	whereis(p0) ! {retrieve_fragment , FragmentId},
	exit(self() , "end of purpose").

retrieveFragment(FragmentId) ->
	spawn(?MODULE , calculateRetrieve , [FragmentId]).


calculateMedian() ->
	whereis(p0) ! find_median,
	exit(self() , "end of purpose").

findMedian() ->
	spawn(?MODULE , calculateMedian , []).


%% ---------- Unused Functions ----------


loop() ->
    receive

        {Exit , PID} -> 
	      {k, F} = file:open("exit.txt", [read, write]),
	      io:write({F, donnie, "Donnie Pinkston"}),
	      file:close(F),
	      io:format("@@@@@@@@@ ~p @@@@@@@@ | ~p |~n", [PID , Exit]);
	{Exit , PID , normal} -> 
	      io:format("@@@@@@@@@ ~p @@@@@@@@ | ~p |~n", [PID , Exit]),
	      {k, F} = file:open("exit.txt", [read, write]),
	      io:format("~p.~n",[{F, donnie, "Donnie Pinkston"}]),
	      file:close(F),
	      exit(normal);
        {Exit , PID , Reason} -> 
	      {k, F} = file:open("exit.txt", [read, write]),
	      io:write({F, donnie, "Donnie Pinkston"}),
	      file:close(F),
	      io:format("@@@@@@@@@ ~p @@@@@@@@ | ~p | | ~p |~n", [PID , Exit , Reason])
    end,
    loop().



%% change according to the secrets
updateMinMaxAvg(NeighborSecret) ->
	MySecret = get('secret'),
	HisSecret = lists:nth(1 , NeighborSecret),
	{_ , HisValue} = HisSecret,
	
	if
		length(MySecret) == (0) ->
			MyNumber = get('number'),
			io:format("~p",[MyNumber]);
			%%Max = findMax(HisValue,MyNumber);
			%%Avg = findAvg2(HisValue,MyNumber);
			%%Min = findMin(HisValue,MyNumber);
		true ->
			MySingleSecret = lists:nth(1 , MySecret),
			{_ , MyValue} = MySingleSecret
			%%Max = findMax(HisValue,MyValue)
			%%Avg = findAvg2(HisValue,MyValue)
			%%Min = findMin(HisValue,MyValue)
	end,

	%%MyNewSecret = [{max , Max}],
	%%MyNewSecret = [{avg , Avg}],
	%%MyNewSecret = [{min , Min}],
	Me = get('number'),
	if
		(Me rem 10) == (0) ->
		     	 %%io:format("Result | ~p | | ~p |~n",[get('name') , Max]);
		     	 %%io:format("Result | ~p | | ~p |~n",[get('name') , Avg]);
		     	 %%io:format("Result | ~p | | ~p |~n",[get('name') , Min]);
			 true;
		true ->
			 io:format("")
	end.
	%%put(secret , (MyNewSecret)).
	

updateFrag(NeighborSecret) ->
	MySecret = get('secret'),
	if
		length(NeighborSecret) /=0 ->
			HisSecret = lists:nth(1 , NeighborSecret),
			{_ , HisId , HisValue} = HisSecret,
			IsSecret = lists:member(HisSecret , MySecret),	
			if
				IsSecret == (false) ->
			 		 MyNewSecret = [HisSecret | MySecret];
				true ->
					MyNewSecret = MySecret
			end,
	 		 MyFragId = get('fragmentId'),
	 		 if
				HisId == (MyFragId) ->
      	 	      		      put(fragmentValue , (HisValue));
				true ->
		      		     io:format("")
	 		end,
			MyNumber = get('number'),
			if
				(MyNumber rem trunc(?LIMIT/4)) == (0) ->
		     			  io:format("Result | ~p | | ~p , ~p | | ~p | | ~p ~p | | ~p |~n",[get('name') , get('fragmentId') , get('fragmentValue') , get('secret') , HisId , HisValue , IsSecret]);
				true ->
				     io:format("")
			end,
			put(secret , (MyNewSecret));
		true ->
		     io:format("")
	end.


buildSecretUpdate(NeighborSecret , 0) ->
	io:format("");
buildSecretUpdate(NeighborSecret , I) ->
	Secret = lists:nth(I , NeighborSecret),
	IsSecret = lists:member(Secret , get('secret')),
	if
		IsSecret == (false) ->
			NewSecret = [{max,get('number')} | get('secret')],
			put(secret , (NewSecret));
		true ->
			io:format("")
	end,
	buildSecretUpdate(NeighborSecret , I-1).
buildSecretMinMaxAvg(NeighborSecret , I) ->
	{Secret , _ , _} = lists:nth(I , NeighborSecret),
	IsSecret = lists:keysearch(Secret , 1 , get('secret')),
	if
		IsSecret == (false) ->
			NewSecret = [{max,get('number')} | get('secret')],
			put(secret , (NewSecret));
		true ->
			io:format("")
	end,
	buildSecretMinMaxAvg(NeighborSecret , I-1).
