%  @copyright 2010 Konrad-Zuse-Zentrum fuer Informationstechnik Berlin

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

%%% @author Nico Kruber <kruber@zib.de>
%%% @doc    Generic code for routing table implementations.
%%%         
%%%         Note: Including modules need to provide some types and functions,
%%%         i.e. rt(), key(), export_rt_to_dht_node/4, to_pid_list/1
%%% @end
%% @version $Id$

%% @doc Notifies the dht_node and failure detector if the routing table changed.
%%      Provided for convenience (see check/6).
-spec check(Old::rt(), New::rt(), key(), node:node_type(),
            node:node_type()) -> ok.
check(Old, New, Id, Pred, Succ) ->
    check(Old, New, Id, Pred, Succ, true).

%% @doc Notifies the dht_node if the routing table changed. Also updates the
%%      failure detector if ReportToFD is set.
-spec check(Old::rt(), New::rt(), MyId::key(), Pred::node:node_type(),
            Succ::node:node_type(), ReportToFD::boolean()) -> ok.
check(X, X, _Id, _Pred, _Succ, _) ->
    ok;
check(OldRT, NewRT, Id, Pred, Succ, true) ->
    Pid = process_dictionary:get_group_member(dht_node),
    comm:send_local(Pid, {rt_update, export_rt_to_dht_node(NewRT, Id, Pred, Succ)}),
    check_fd(NewRT, OldRT);
check(_OldRT, NewRT, Id, Pred, Succ, false) ->
    Pid = process_dictionary:get_group_member(dht_node),
    comm:send_local(Pid, {rt_update, export_rt_to_dht_node(NewRT, Id, Pred, Succ)}).

%% @doc Updates the failure detector in case the routing table changed.
-spec check_fd(Old::rt(), New::rt()) -> ok.
check_fd(X, X) ->
    ok;
check_fd(NewRT, OldRT) ->
    NewPids = to_pid_list(NewRT),
    OldPids = to_pid_list(OldRT),
    fd:update_subscriptions(OldPids, NewPids).
