%  @copyright 2007-2012 Zuse Institute Berlin

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

%% @author Thorsten Schuett <schuett@zib.de>
%% @doc    Supervisor for each DHT node that is responsible for keeping
%%         processes running that run for themselves.
%%
%%         If one of the supervised processes fails, only the failed process
%%         will be re-started!
%% @end
%% @version $Id$
-module(sup_dht_node).
-author('schuett@zib.de').
-vsn('$Id$ ').

-behaviour(supervisor).
-include("scalaris.hrl").

-export([start_link/1, init/1]).
-export([supspec/1, childs/1]).

-spec start_link(tuple())
        -> {ok, Pid::pid(), pid_groups:groupname()} | ignore |
               {error, Error::{already_started, Pid::pid()} | shutdown | term()}.
start_link({DHTNodeGroup, Options}) ->
    case supervisor:start_link(?MODULE, [{DHTNodeGroup, Options}]) of
        {ok, Pid} -> {ok, Pid, DHTNodeGroup};
        X         -> X
    end.

%% userdevguide-begin sup_dht_node:init
-spec init([{pid_groups:groupname(), [tuple()]}])
        -> {ok, {{one_for_one, MaxRetries::pos_integer(),
                  PeriodInSeconds::pos_integer()}, []}}.
init([{DHTNodeGroup, _Options}] = X) ->
    pid_groups:join_as(DHTNodeGroup, ?MODULE),
    mgmt_server:connect(),
    supspec(X).
%% userdevguide-end sup_dht_node:init

-spec supspec(any()) -> {ok, {{one_for_one, MaxRetries::pos_integer(),
                         PeriodInSeconds::pos_integer()}, []}}.
supspec(_) ->
    {ok, {{one_for_one, 10, 1}, []}}.

-spec childs([{pid_groups:groupname(), Options::[tuple()]}]) ->
                    [ProcessDescr::supervisor:child_spec()].
childs([{DHTNodeGroup, Options}]) ->
    Cyclon = util:sup_worker_desc(cyclon, cyclon, start_link, [DHTNodeGroup]),
    DC_Clustering =
        util:sup_worker_desc(dc_clustering, dc_clustering, start_link,
                             [DHTNodeGroup]),
    DeadNodeCache =
        util:sup_worker_desc(deadnodecache, dn_cache, start_link,
                             [DHTNodeGroup]),
    Delayer =
        util:sup_worker_desc(msg_delay, msg_delay, start_link,
                             [DHTNodeGroup]),
    Gossip =
        util:sup_worker_desc(gossip, gossip, start_link, [DHTNodeGroup]),
    Reregister =
        util:sup_worker_desc(dht_node_reregister, dht_node_reregister,
                             start_link, [DHTNodeGroup]),
    RoutingTable =
        util:sup_worker_desc(routing_table, rt_loop, start_link,
                             [DHTNodeGroup]),
    SupDHTNodeCore_AND =
        util:sup_supervisor_desc(sup_dht_node_core, sup_dht_node_core,
                                 start_link, [DHTNodeGroup, Options]),
    Vivaldi =
        util:sup_worker_desc(vivaldi, vivaldi, start_link, [DHTNodeGroup]),
    Monitor =
        util:sup_worker_desc(monitor, monitor, start_link, [DHTNodeGroup]),
    MonitorPerf =
        util:sup_worker_desc(monitor_perf, monitor_perf, start_link, [DHTNodeGroup]),
    RepUpdate =
        case config:read(rrepair_enabled) of
            true -> util:sup_worker_desc(rrepair, rrepair, start_link, [DHTNodeGroup]);
            _ -> []
        end,
    lists:flatten([ %% RepUpd may be [] and lists:flatten eliminates this
                    Monitor,
                    Delayer,
                    Reregister,
                    DeadNodeCache,
                    RoutingTable,
                    Cyclon,
                    Vivaldi,
                    DC_Clustering,
                    Gossip,
                    SupDHTNodeCore_AND,
                    MonitorPerf,
                    RepUpdate
           ]).
