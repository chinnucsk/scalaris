%  Copyright 2007-2008 Konrad-Zuse-Zentrum für Informationstechnik Berlin
%
%   Licensed under the Apache License, Version 2.0 (the "License");
%   you may not use this file except in compliance with the License.
%   You may obtain a copy of the License at
%
%       http://www.apache.org/licenses/LICENSE-2.0
%
%   Unless required by applicable law or agreed to in writing, software
%   distributed under the License is distributed on an "AS IS" BASIS,
%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%   See the License for the specific language governing permissions and
%   limitations under the License.
%%%-------------------------------------------------------------------
%%% File    : cs_api.erl
%%% Author  : Thorsten Schuett <schuett@zib.de>
%%% Description : Chord# API
%%%
%%% Created : 16 Apr 2007 by Thorsten Schuett <schuett@zib.de>
%%%-------------------------------------------------------------------
%% @author Thorsten Schuett <schuett@zib.de>
%% @copyright 2007-2008 Konrad-Zuse-Zentrum für Informationstechnik Berlin
%% @version $Id$
-module(cs_api).

-author('schuett@zib.de').
-vsn('$Id$ ').

-export([process_request_list/2, read/1, write/2, delete/1,
         test_and_set/3, range_read/2]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Public Interface
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @type key() = term(). Key
%% @type value() = term(). Value

process_request_list(TLog, ReqList) ->
    erlang:put(instance_id, process_dictionary:find_group(cs_node)),
    % should just call transstore.transaction_api:process_request_list
    % for parallel quorum reads and scan for commit request to actually do
    % the transaction
    % and there should scan for duplicate keys in ReqList
    % commit is only allowed as last element in ReqList
    {TransLogResult, ReverseResultList} =
        lists:foldl(
          fun(Request, {AccTLog, AccRes}) ->
                  {NewAccTLog, SingleResult} = process_request(AccTLog, Request),
                  {NewAccTLog, [SingleResult | AccRes]}
          end,
          {TLog, []}, ReqList),
    {{translog, TransLogResult}, {results, lists:reverse(ReverseResultList)}}.

process_request(TLog, Request) ->
    case Request of
        {read, Key} ->
            case transstore.transaction_api:read(Key, TLog) of
                {{value, Val}, NTLog} ->
                    {NTLog, {read, Key, {value, Val}}};
                {{fail, Reason}, NTLog} ->
                    {NTLog, {read, Key, {fail, Reason}}}
            end;
        {write, Key, Value} ->
            case transstore.transaction_api:write(Key, Value, TLog) of
                {ok, NTLog} ->
                    {NTLog, {write, Key, {value, Value}}};
                {{fail, Reason}, NTLog} ->
                    {NTLog, {write, Key, {fail, Reason}}}
            end;
        {commit} ->
            case transstore.transaction_api:commit(TLog) of
                {ok} ->
                    {TLog, {commit, ok, {value, "ok"}}};
                {fail, Reason} ->
                    {TLog, {commit, fail, {fail, Reason}}}
            end
    end.

%% @doc reads the value of a key
%% @spec read(key()) -> {failure, term()} | value()
read(Key) ->
    case transstore.transaction_api:quorum_read(Key) of
        {fail, Reason} ->
	       {fail, Reason};
        {Value, _Version} ->
	       Value
    end.

%% @doc writes the value of a key
%% @spec write(key(), value()) -> ok | {fail, term()}
write(Key, Value) ->
    case transstore.transaction_api:single_write(Key, Value) of
	commit ->
	    ok;
	{fail, Reason} ->
	    {fail, Reason}
    end.

delete(Key) ->
    transstore.transaction_api:delete(Key, 2000).

%% @doc atomic compare and swap
%% @spec test_and_set(key(), value(), value()) -> {fail, Reason} | ok
test_and_set(Key, OldValue, NewValue) ->
    TFun = fun(TransLog) ->
                   {Result, TransLog1} = transstore.transaction_api:read(Key, TransLog),
                   case Result of
                       {value, ReadValue} ->
                           if
                               ReadValue == OldValue ->
                                   {Result2, TransLog2} = transstore.transaction_api:write(Key, NewValue, TransLog1),
                                   if
                                       Result2 == ok ->
                                           {{ok, done}, TransLog2};
                                       true ->
                                           {{fail, notfound}, TransLog2}
                                   end;
                               true ->
                                   {{fail, {key_changed, ReadValue}}, TransLog1}
                           end;
                       {fail, not_found} ->
                           {Result2, TransLog2} = transstore.transaction_api:write(Key, NewValue, TransLog),
                           if
                               Result2 == ok ->
                                   {{ok, done}, TransLog2};
                               true ->
                                   {{fail, write}, TransLog2}
                           end
                       end
           end,
    SuccessFun = fun(X) -> {success, X} end,
    FailureFun = fun(X) -> {failure, X} end,
    case do_transaction_locally(TFun, SuccessFun, FailureFun, 5000) of
	{trans, {success, {commit, done}}} ->
	    ok;
	{trans, {failure, Reason}} ->
	    {fail, Reason};
	X ->
	   log:log(warn,"[ Node ~w ] ~p", [self(),X]),
	    X
    end.


% I know there is a cs_node in this instance so I will use it directly
%@private
do_transaction_locally(TransFun, SuccessFun, Failure, Timeout) ->
    {ok, PID} = process_dictionary:find_cs_node(),
    PID ! {do_transaction, TransFun, SuccessFun, Failure, cs_send:this()},
    receive
	X ->
	    X
    after
	Timeout ->
	   do_transaction_locally(TransFun, SuccessFun, Failure, Timeout)
    end.

%@doc range a range of key-value pairs
range_read(From, To) ->
    Interval = intervals:new(From, To),
    bulkowner:issue_bulk_owner(Interval, 
			       {bulk_read_with_version, cs_send:this()}),
    erlang:send_after(5000, self(), {timeout}),
    range_read_loop(Interval, [], []).

range_read_loop(Interval, Done, Data) ->
    receive
	{timeout} ->
	    {timeout, lists:flatten(Data)};
	{bulk_read_with_version_response, {From, To}, NewData} ->
	    Done2 = [intervals:new(From, To) | Done],
	    case intervals:is_covered(Interval, Done2) of
		false ->
		    range_read_loop(Interval, Done2, [NewData | Data]);
		true ->
		    {ok, lists:flatten([NewData | Data])}
	    end
    end.
    
    
