%% @author Mochi Media <dev@mochimedia.com>
%% @copyright 2010 Mochi Media <dev@mochimedia.com>

%% @doc Supervisor for the erl_om application.

-module(erl_om_sup).
-author("Mochi Media <dev@mochimedia.com>").

-behaviour(supervisor).

%% External exports
-export([start_link/0, upgrade/0]).

%% supervisor callbacks
-export([init/1]).

%% @spec start_link() -> ServerRet
%% @doc API for starting the supervisor.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% @spec upgrade() -> ok
%% @doc Add processes if necessary.
upgrade() ->
    {ok, {_, Specs}} = init([]),

    Old = sets:from_list(
            [Name || {Name, _, _, _} <- supervisor:which_children(?MODULE)]),
    New = sets:from_list([Name || {Name, _, _, _, _, _} <- Specs]),
    Kill = sets:subtract(Old, New),

    sets:fold(fun (Id, ok) ->
                      supervisor:terminate_child(?MODULE, Id),
                      supervisor:delete_child(?MODULE, Id),
                      ok
              end, ok, Kill),

    [supervisor:start_child(?MODULE, Spec) || Spec <- Specs],
    ok.

%% @spec init([]) -> SupervisorTree
%% @doc supervisor callback.
init([]) ->
    Web = web_specs(erl_om_web),
    Processes = [Web, handler_spec()],
    Strategy = {one_for_one, 10, 10},
    {ok,
     {Strategy, lists:flatten(Processes)}}.

web_specs(Mod) ->
    WebConfig = [{ip, application:get_env(erl_om, ip,{0,0,0,0})},
                 {port, application:get_env(erl_om, port,8080)},
                 {docroot, application:get_env(erl_om, docroot,erl_om_deps:local_path(["priv", "www"]))}],
    {Mod,
     {Mod, start, [WebConfig]},
     permanent, 5000, worker, dynamic}.

handler_spec() ->
    {erl_om_handler,
     {erl_om_handler, start_link, []},
     permanent, 5000, worker, [erl_om_handler]}.
