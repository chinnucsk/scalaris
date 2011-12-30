% @copyright 2010-2011 Zuse Institute Berlin

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

%% @author Maik Lange <malange@informatik.hu-berlin.de>
%% @doc    Less hashing, same performance hash function set container
%%
%%         Implementation of a hash function set proposed in 
%%         2006 by A. Kirsch, M. Mitzenmacher - 
%%         "Less Hashing, Same Performance: Building a Better Bloom Filter 
%%         Build k Hash functions of the form g_i(x) = h_1(X) + i * h_2(X)
%%  
%%         Used MD5 Hash-Function like in 
%%         2000 - L.Fan, P. Cao., JA, ZB : 
%%               "Summary Cache: A Scalable Wide-Area Web Cache Sharing Protocol" 
%%               (Counting Bloom Filters Paper)
%% @end
%% @version $Id$

-module(hfs_lhsp).

% types
-behaviour(hfs_beh).

-type hfs_fun() :: fun((binary()) -> integer() | binary()).
-type hfs_t()   :: {hfs_lhsp, Hf_count::integer(), H1_fun::hfs_fun(), H2_fun::hfs_fun()}.

% include
-include("hfs_beh.hrl").

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% API functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% @doc returns a new lhsp hfs with default functions
new_(HFCount) -> 
    new_([fun erlang:adler32/1, fun erlang:md5/1], HFCount).

new_([H1, H2] = HFList, HFCount) when length(HFList) =:= 2 -> 
    {hfs_lhsp, HFCount, H1, H2};
new_(_, _) ->
    erlang:error("hash function list length =/= 2").

% @doc Applies Val to all hash functions in container HC
apply_val_({hfs_lhsp, K, H1, H2}, Val) ->
    ValBin = term_to_binary(Val),
    HV1 = hash_value(ValBin, H1),
    HV2 = hash_value(ValBin, H2),
    util:for_to_ex(0, K - 1, fun(I) -> HV1 + I * HV2 end).

% @doc Returns number of hash functions in the container
hfs_size_(Hfs) -> 
    {hfs_lhsp, K, _, _} = Hfs,
    K.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% private functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-spec hash_value(binary(), hfs_fun()) -> integer() | binary().
hash_value(Val, HashFun) ->
    H = HashFun(Val),
    case erlang:is_binary(H) of
        true ->
            Size = erlang:bit_size(H),
            <<R:Size>> = H,
            R;
        false -> H
    end.