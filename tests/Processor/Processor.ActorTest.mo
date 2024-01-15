import Array "mo:base/Array";
import Blob "mo:base/Blob";
import D "mo:base/Debug";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Opt "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";

import Itertools "mo:itertools/Iter";
import Star "mo:star/star";
import Vec "mo:vector";

import ActorSpec "../utils/ActorSpec";
import Fake "../fake";
import Processor "../../src/processor";
import MigrationTypes = "../../src/migrations/types";
import T "../../src/migrations/types";

module {

  let base_environment= {
    get_time = null;
    add_ledger_transaction = null;
    get_fee = null;
  };

  
  let Map = Processor.Map;
  //let Vector = Processor.Vector;

  let e8s = 100000000;

  


    public func test() : async ActorSpec.Group {
        D.print("in test");

        let canister : {owner : Principal; subaccount : ?Blob} = {
            owner = Principal.fromText("x4ocp-k7ot7-oiqws-rg7if-j4q2v-ewcel-2x6we-l2eqz-rfz3e-6di6e-jae");
            subaccount = null;
        };

        let {
            assertTrue;
            assertFalse;
            assertAllTrue;
            describe;
            it;
            skip;
            pending;
            run;
        } = ActorSpec;

        let default_processor_args : T.Current.InitArgs = {
            defaultTimeOut = null;
            advancedSettings = null;
        };

        var test_time : Int = Time.now();

        let environment : T.Current.Environment = {
          getTime = (func () : Int {test_time});
          getCanister = func() : Principal{Principal.fromText("jwcfb-hyaaa-aaaaj-aac4q-cai")};
          addLedgerTransaction = null;
          onDataWillBeLoaded = null;
          onDataReady = null;
          onPreProcess = null;
          onProcess = null;
          onPostProcess = null;
          onDataWillBeReturned = null;
          onDataReturned = null;
          getProcessType = null;
          putLocalWorkspace = null;
          getLocalWorkspace = null;
        };


        func get_processor(args : Processor.InitArgs) : Processor.ICRC48{

          let processor = Processor.init(Processor.initialState(), #v0_1_0(#id),?args, canister.owner);

          Processor.ICRC48(?processor, canister.owner, environment);
        };

        func get_icrc_env(args : Processor.InitArgs, env : Processor.Environment) : Processor.ICRC48{

          let processor = Processor.init(Processor.initialState(), #v0_1_0(#id),?args, canister.owner);

          Processor.ICRC48(?processor, canister.owner, env);
        };

        return describe(
            "Processor Tests",
            [
                it(
                    "init()",
                    do {
                        let processor  = get_processor(default_processor_args);
                        let stats = processor.getStats();

                        // returns without trapping
                        assertAllTrue([
                            stats.nonce == 0,
                            stats.workspaceCount  ==0,
                            stats.requestCount == 0,
                            stats.processCount == 0,
                            stats.responseCount == 0,
                            stats.pendingDataReturnedNotifications  == 0,
                            stats.pendingStepProcessing  == 0,
                            stats.processTimer == null,
                            stats.cleanUpTimer == null,
                           
                            stats.config.defaultTimeOut == 120_000_000_000,
                            stats.config.maxChunkSize == 2000000,
                            stats.config.maxClean == 1000,
                            stats.config.maxParallelSteps == 8,
                            
                        ]);
                    },
                ),


            ],
        );
    };

    
};
