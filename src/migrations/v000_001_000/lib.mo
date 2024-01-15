import MigrationTypes "../types";
import v0_1_0 "types";

import D "mo:base/Debug";
import Opt "mo:base/Option";
import Itertools "mo:itertools/Iter";

import Vec "mo:vector";
import Map "mo:map9/Map";
import Set "mo:map9/Set";

module {

  public func upgrade(prevmigration_state: MigrationTypes.State, args: MigrationTypes.Args, caller: Principal): MigrationTypes.State {

    let {
       advancedSettings;
       defaultTimeOut;
    } = switch(args){
      case(?args) {
        {
          defaultTimeOut = Opt.get<Int>(args.defaultTimeOut,v0_1_0.defaultTimeOut);
          advancedSettings = args.advancedSettings;
        }
      };
      case(null) {{
          defaultTimeOut = v0_1_0.defaultTimeOut;
          advancedSettings = null;
        }
      };
    };

    var existingWorkspaceCache = switch(advancedSettings){
      case(null) [];
      case(?val) val.existingWorkspaceCache;
    };
    
    let workspaceCache = Map.fromIter<Nat, ?MigrationTypes.Current.WorkspaceCache>(existingWorkspaceCache.vals(), Map.nhash);

    var existingRequestCache = switch(advancedSettings){
      case(null) [];
      case(?val) val.existingRequestCache;
    };
    
    let requestCache = Map.fromIter<Nat, ?MigrationTypes.Current.RequestCache>(existingRequestCache.vals(), Map.nhash);


    var existingProcessCache = switch(advancedSettings){
      case(null) [];
      case(?val) val.existingProcessCache;
    };
    
    let processCache = Map.fromIter<Nat, ?MigrationTypes.Current.ProcessCache>(existingProcessCache.vals(), Map.nhash);

    var existingResponseCache = switch(advancedSettings){
      case(null) [];
      case(?val) val.existingResponseCache;
    };
    
    let responseCache = Map.fromIter<Nat, ?MigrationTypes.Current.ResponseCache>(existingResponseCache.vals(), Map.nhash);

    let pendingDataReturnedNotifications = switch(advancedSettings){
      case(null) Set.new<Nat>();
      case(?val) Set.fromIter<Nat>(val.existingDataReturnedNotifications.vals(), Set.nhash);
    };

    let pendingStepProcessing = switch(advancedSettings){
      case(null) Set.new<Nat>();
      case(?val) Set.fromIter<Nat>(val.existingStepProcessing.vals(), Set.nhash);
    };

    
    

    let nonce = switch(advancedSettings){
      case(null) 0;
      case(?val){
        val.existingNonce;
      };
    };


    let state : MigrationTypes.Current.State = {
      var nonce = nonce;
      var workspaceCache = workspaceCache;
      var requestCache = requestCache;
      var processCache = processCache;
      var responseCache = responseCache;
      var pendingDataReturnedNotifications = pendingDataReturnedNotifications;
      var pendingStepProcessing = pendingStepProcessing;
      var processTimer  = null;
      var cleanUpTimer = null;
      var minExpiration = v0_1_0.THEFUTURE;
      config = {
        var defaultTimeOut = defaultTimeOut;
        var maxClean = 1000;
        var maxParallelSteps = 8;
        var maxChunkSize = 2000000;
      }
    };

    return #v0_1_0(#data(state));
  };

  public func downgrade(prev_migration_state: MigrationTypes.State, args: MigrationTypes.Args, caller: Principal): MigrationTypes.State {

    return #v0_0_0(#data);
  };

};