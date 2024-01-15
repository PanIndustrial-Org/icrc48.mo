import Migrations "./migrations";
import MigrationTypes "./migrations/types";

import Array "mo:base/Array";
import D "mo:base/Debug";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Opt "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Timer "mo:base/Timer";
import Icrc1 "mo:fuzz/ICRC1";

module {

  let debug_channel = {
    announce = false;
    process = false;
    pull = false;
    dataView = false;
    push = true;
    parallel = false;
    returnData = false;
    singleStep = false;
  };

  public type State = MigrationTypes.State;
  
  public type CurrentState = MigrationTypes.Current.State;
  public type Stats = MigrationTypes.Current.Stats;
  public type Environment = MigrationTypes.Current.Environment;
  public type InitArgs = MigrationTypes.Current.InitArgs;


  public type ProcessRequest = MigrationTypes.Current.ProcessRequest;
  public type ProcessResponse = MigrationTypes.Current.ProcessResponse;
  public type ProcessError = MigrationTypes.Current.ProcessError;
  public type ProcessType = MigrationTypes.Current.ProcessType;
  public type PipelineEventResponse = MigrationTypes.Current.PipelineEventResponse;
  
  public type PipeInstanceID = MigrationTypes.Current.PipeInstanceID;

  public type RequestCache = MigrationTypes.Current.RequestCache;
  public type WorkspaceCache = MigrationTypes.Current.WorkspaceCache;
  public type ProcessCache = MigrationTypes.Current.ProcessCache;
  public type ResponseCache = MigrationTypes.Current.ResponseCache;

  public type StepRequest = MigrationTypes.Current.StepRequest;
  public type PushStatusRequest = MigrationTypes.Current.PushStatusRequest;

  public type ChunkPush = MigrationTypes.Current.ChunkPush;
  public type ChunkGet = MigrationTypes.Current.ChunkGet;
  public type ChunkResponse = MigrationTypes.Current.ChunkResponse;

  public type ProcessingStatusRequest = MigrationTypes.Current.ProcessingStatusRequest;

  /// # `initialState`
  ///
  /// Creates and returns the initial state of the processor.
  ///
  /// ## Returns
  ///
  /// `State`: The initial state object based on the `v0_0_0` version specified by the `MigrationTypes.State` variant.
  ///
  /// ## Example
  ///
  /// ```
  /// let state = ICRC2.initialState();
  /// ```
  public func initialState() : State {#v0_0_0(#data)};

  /// # currentStateVersion
  ///
  /// Indicates the current version of the processor implementation is using.
  /// It is used for data migration purposes to ensure compatibility across different ledger state formats.
  ///
  /// ## Value
  ///
  /// `#v0_1_0(#id)`: A unique identifier representing the version of the ledger state format currently in use, as defined by the `State` data type.
  public let currentStateVersion = #v0_1_0(#id);


  public let init = Migrations.migrate;

  public let CandyTypes = MigrationTypes.Current.CandyTypes;
  public let Map = MigrationTypes.Current.Map;
  public let Set = MigrationTypes.Current.Set;
  public let Star = MigrationTypes.Current.Star;
  public let SB = MigrationTypes.Current.SB;
  public let Vec = MigrationTypes.Current.Vector;
  public let Workspace = MigrationTypes.Current.Workspace;


  public class ICRC48(stored: ?State, canister: Principal, environment: Environment){


    var state : CurrentState = switch(stored){
      case(null) {
        let #v0_1_0(#data(foundState)) = init(initialState(),currentStateVersion, null, canister);
        foundState;
      };
      case(?val) {
        let #v0_1_0(#data(foundState)) = init(val,currentStateVersion, null, canister);
        foundState;
      };
    };

    public let migrate = Migrations.migrate;

    public func getState() : CurrentState{
      return state;
    };

    public func getStats() : Stats{
      return {
        nonce = state.nonce;
        workspaceCount  = Map.size(state.workspaceCache) ;
        requestCount = Map.size(state.requestCache);
        processCount = Map.size(state.processCache);
        responseCount = Map.size(state.responseCache);
        pendingDataReturnedNotifications  =  Set.size(state.pendingDataReturnedNotifications);
        pendingStepProcessing  = Set.size(state.pendingStepProcessing);
        processTimer = state.processTimer;
        cleanUpTimer = state.cleanUpTimer;
        config = {
          defaultTimeOut = state.config.defaultTimeOut;
          maxChunkSize = state.config.maxChunkSize;
          maxClean = state.config.maxClean;
          maxParallelSteps = state.config.maxParallelSteps;
        };
      };
    };

    private func getPipeInstanceID(request: ProcessRequest) : Result.Result<PipeInstanceID, ProcessError> {
      state.nonce += 1;
      
      let expiresAt = switch(request.expiresAt){
        case(null){
          environment.getTime() + state.config.defaultTimeOut;
        };
        case(?val){
          if(val > environment.getTime()){
            return #err{message = "Expired"; error_code = 33;};
          };
          environment.getTime() + val;
        };
      };

      if(expiresAt < state.minExpiration){
        state.minExpiration := expiresAt;
        switch(state.cleanUpTimer){
          case(?val){
            Timer.cancelTimer(val);
          };
          case(_){};
        };
        let timeUntilNextExpiration = state.minExpiration - environment.getTime();
        state.cleanUpTimer := ?Timer.setTimer(#seconds((Int.abs(timeUntilNextExpiration) + 1000000000)/1000000000), handleProcessTimer);
      };



      let thisHash = state.nonce;
      ignore Map.put<Nat, ?RequestCache>(state.requestCache, Map.nhash, thisHash, ?{
          expiresAt = expiresAt;
          request = {
              caller = request.caller;
              event = request.event;
              expiresAt = request.expiresAt;
              dataConfig = switch(request.dataConfig){
                  case(?#DataIncluded(data)){?#Internal;};
                  case(?#Local(data)){?#Local(data);};
                  case(?#Push(val)){?#Push(val)};
                  case(?#Internal){?#Internal};
                  case(null){
                    return #err({
                      message = "Improper Data Config - null";
                      error_code = 23;
                    });
                  };
              };
              createdAt = request.createdAt;
              executionConfig = request.executionConfig;
              responseConfig = request.responseConfig;};
          timestamp = environment.getTime();
          status = #Initialized;
      });

      return #ok(thisHash);
    }; 

 


    public func process(request : ProcessRequest) : async Result.Result<ProcessResponse, ProcessError> {

      

      //file the request and alert to new data
      //assign a hash
      let pipeInstanceID = switch(getPipeInstanceID(request)){
        case(#ok(val)) val;
        case(#err(err)){
          return #err(err);
        };
      };

      debug if(debug_channel.process) D.print("a process initiated " # debug_show(pipeInstanceID) );

      var thisWorkspace = Workspace.emptyWorkspace();



      //check the data
      switch(request.dataConfig){
          case(?#Local(_id)){
            // Data may already reside on this server.  In this path way we will
            // ask the local environment to provide the data workspace for processing.

            // the server may need to do some preprocessing of the workspace. this event alerts the environemnt 
            let dataWillLoadResponse = switch(environment.onDataWillBeLoaded){
              case(?envfunc){
                switch(await* envfunc(pipeInstanceID, ?request)){
                  case(#trappable(val)) val;
                  case(#awaited(val)) val;
                  case(#err(#awaited(val))) #Error(val);
                  case(#err(#trappable(val))) #Error(val);
                };
              };
              case(null)#DataNoOp;
            };

            switch(dataWillLoadResponse){
              case(#Error(err)) return #err(err);
              case(#Assigned(assignment)){ 
                ignore Map.put<Nat, ?WorkspaceCache>(state.workspaceCache, Map.nhash, pipeInstanceID, ?{
                    var status = ?#Assigned(assignment);
                    data = Workspace.emptyWorkspace();
                });
                return #ok(?#Assigned({canister = assignment; pipeInstanceID = pipeInstanceID;}));
              };
              case(_){};
            };

            //load the workspace from the local environment
            thisWorkspace := switch(environment.getLocalWorkspace){
              case(?envfunc) envfunc(pipeInstanceID, _id, ?request);
              case(null) Workspace.emptyWorkspace();
            };

            ignore Map.put<Nat, ?WorkspaceCache>(state.workspaceCache, Map.nhash, pipeInstanceID, ?{
                var status = ?#Initialized;
                data = thisWorkspace;
            });

            debug if(debug_channel.process) D.print("workspace included" # debug_show(SB.size(thisWorkspace)));

            //alerts the local environment that the data has been initialized and it may now do clean up
            let dataResponse = switch(environment.onDataReady){
              case(?envfunc){
                switch(await* envfunc(pipeInstanceID, thisWorkspace, ?request)){
                  case(#trappable(val)) val;
                  case(#awaited(val)) val;
                  case(#err(#awaited(val))) #Error(val);
                  case(#err(#trappable(val))) #Error(val);
                };
              };
              case(null)#DataNoOp;
            };
            
            switch(dataResponse){
              case(#Error(err)){
              
                 return #err(err);
              };
              case(_){};
            };
          };
          case(?#DataIncluded(dataIncludedRequest)){
            // In this data configuration, the data necessary for processing has been included with the request.


            debug if(debug_channel.dataView) D.print("data included" # debug_show(dataIncludedRequest.data));

            // the server may need to do some preprocessing of the workspace. this event alerts the environemnt 
            let dataWillLoadResponse = switch(environment.onDataWillBeLoaded){
              case(?envfunc){
                switch(await* envfunc(pipeInstanceID, ?request)){
                  case(#trappable(val)) val;
                  case(#awaited(val)) val;
                  case(#err(#awaited(val))) #Error(val);
                  case(#err(#trappable(val))) #Error(val);
                };
              };
              case(null)#DataNoOp;
            };

            switch(dataWillLoadResponse){
              case(#Error(err)) return #err(err);
              case(#Assigned(assignment)) { 
                ignore Map.put<Nat, ?WorkspaceCache>(state.workspaceCache, Map.nhash, pipeInstanceID, ?{
                    var status = ?#Assigned(assignment);
                    data = Workspace.emptyWorkspace();
                });
                return #ok(?#Assigned({canister = assignment; pipeInstanceID = pipeInstanceID;}));
              };
              case(_){};
            };

            //included data is pumpped into the workspace
            thisWorkspace := Workspace.fromAddressedChunks(dataIncludedRequest.data);

            debug if(debug_channel.process) D.print("workspace included" # debug_show(SB.size(thisWorkspace)));

            let dataResponse = switch(environment.onDataReady){
              case(?envfunc){
                switch(await* envfunc(pipeInstanceID, thisWorkspace, ?request)){
                  case(#trappable(val)) val;
                  case(#awaited(val)) val;
                  case(#err(#awaited(val))) #Error(val);
                  case(#err(#trappable(val))) #Error(val);
                };
              };
              case(null)#DataNoOp;
            };
            
            switch(dataResponse){
              case(#Error(err)) return #err(err); //no clean up necessar because we don't have any state yet.
              case(_){};
            };
          };
          case(?#Push(?pusher)){
            //we are basically done here. We need the user to push us data so we can continue. We do need to send the cache key.
            debug if(debug_channel.push) D.print("this is a push operation");
            let dataWillLoadResponse = switch(environment.onDataWillBeLoaded){
              case(?envfunc){
                switch(await* envfunc(pipeInstanceID, ?request)){
                  case(#trappable(val)) val;
                  case(#awaited(val)) val;
                  case(#err(#awaited(val))) #Error(val);
                  case(#err(#trappable(val))) #Error(val);
                };
              };
              case(null)#DataNoOp;
            };

            switch(dataWillLoadResponse){
              case(#Error(err)) return #err(err);
              case(#Assigned(assignment)) { 
                ignore Map.put<Nat, ?WorkspaceCache>(state.workspaceCache, Map.nhash, pipeInstanceID, ?{
                    var status = ?#Assigned(assignment);
                    data = Workspace.emptyWorkspace();
                });
                return #ok(?#Assigned({canister = assignment; pipeInstanceID = pipeInstanceID;}));
              };
              case(_){};
            };

          
            //todo: maybe we require initialization
            ignore Map.put<Nat, ?WorkspaceCache>(state.workspaceCache, Map.nhash, pipeInstanceID, ?{
                var status = ?#Initialized;
                data = Workspace.emptyWorkspace();
            });

            return #ok(?#IntakeNeeded(?{
                pipeInstanceID = pipeInstanceID;
                currentChunks = 0;
                totalChunks = pusher.totalChunks;
                chunkMap = [] : [Bool];
            }) : ProcessResponse);
          };
          case(?#Push(null)){
            return #err{message = "Push config missing"; error_code = 30;};
          };
          case(?#Internal){
              return #err{message = "Internal should not be used for initial request."; error_code = 178;};
          };
          case(null){
              return #err{message = "Internal should not be used for initial request."; error_code = 178;};
          }
      };



      //process the data
      //todo: make sure we skip this for single steps that aren't a push procedure
      let processingResult = await* handleProcessing(pipeInstanceID, thisWorkspace, ?request, null);

      switch(processingResult){
          case(#ok(data)){
              D.print("push branch processing results" # debug_show(data));
              if(handleParallelProcessStepResult(pipeInstanceID, null, {bFinished = data.bFinished; data = thisWorkspace} ) == true){
                  //more processing needed

                  return #ok(?#StepProcess(?{
                      pipeInstanceID = pipeInstanceID;
                      status = switch(environment.getProcessType){
                        case(null) ?#Unconfigured;
                        case(?envfunc) envfunc(pipeInstanceID, thisWorkspace,?request);
                      };
                  }));
              };
          };
          case(#err(theError)){
              return #err(theError);
          }
      };


      //return the data
      let returnData = await* handleReturn(pipeInstanceID, thisWorkspace, ?request);

      return returnData;
    };


    private func handleProcessing(pipeInstanceID : PipeInstanceID, data: CandyTypes.Workspace, request : ?ProcessRequest, step: ?Nat) : async* Result.Result<{bFinished: Bool}, ProcessError> {
      //process the data
      let foundRequest = switch(request){
        case(null){
          switch(Map.get<Nat, ?RequestCache>(state.requestCache, Map.nhash, pipeInstanceID)){
            case(null){
              return #err({error_code=24; message = "cannot find request in cache"});
            };
            case(??val) val.request;
            case(?null){
              return #err({error_code=24; message = "cannot find request in cache"});
            };
          };
        };
        case(?val) val;
      };

      switch(foundRequest.executionConfig){
        case(null) return #err({error_code =25; message ="Improper Execution Config"});
        case(?#OnLoad){
            debug if(debug_channel.process) D.print("handling onLoad - Preprocess");
            let preProcessResponse = switch(environment.onPreProcess){
              case(null) #DataNoOp;
              case(?envfunc){
                switch(await* envfunc(pipeInstanceID, data, ?foundRequest, step)){
                  case(#trappable(val)) val;
                  case(#awaited(val)) val;
                  case(#err(#awaited(val))) #Error(val);
                  case(#err(#trappable(val))) #Error(val);
                };
              };
            };

            switch(preProcessResponse){
              case(#Error(err)) return #err(err);
              case(_){};
            };

            debug if(debug_channel.process) D.print("handling onLoad - process");
            let response : PipelineEventResponse =  switch(environment.onProcess){
              case(null) #DataNoOp;
              case(?envfunc) {
                switch(await* envfunc(pipeInstanceID, data, ?foundRequest, step)){
                  case(#trappable(val)) val;
                  case(#awaited(val)) val;
                  case(#err(#awaited(val))) #Error(val);
                  case(#err(#trappable(val))) #Error(val);
                };
              };
            };

            switch(response){
                case(#DataUpdated){
                    debug if(debug_channel.process) D.print("setting processedData");
                    //processedData := data.newData;
                };
                case(#StepNeeded){
                    debug if(debug_channel.process) D.print("more processing needed a");

                    Set.add<Nat>(state.pendingStepProcessing, Set.nhash, pipeInstanceID);
                    if(state.processTimer == null){
                      state.processTimer := ?Timer.setTimer(#seconds(0), handleProcessTimer);
                    };
                    return #ok{bFinished=false};
                };
                case(#Error(err)){
                    debug if(debug_channel.process) D.print("Error occured" # debug_show(response));
                    return #err(err);
                };
                case(#Assigned(err)){
                    debug if(debug_channel.process) D.print("Item assigned" # debug_show(response));
                    return #err({error_code=24; message = "processing assigned item"});
                };
                case(#DataNoOp){
                   debug if(debug_channel.process) D.print("no op");
                };
                
            };

            debug if(debug_channel.process) D.print("handling onLoad - postProcess");
            let postProcessResponse = switch(environment.onPostProcess){
              case(null) #DataNoOp;
              case(?envfunc) {
                switch(await* envfunc(pipeInstanceID, data, ?foundRequest, step)){
                  case(#trappable(val)) val;
                  case(#awaited(val)) val;
                  case(#err(#awaited(val))) #Error(val);
                  case(#err(#trappable(val))) #Error(val);
                };
              };
            };

            switch(preProcessResponse){
              case(#Error(err)) return #err(err);
              case(_){};
            };
            return #ok({bFinished=true});
        };
        case(?#Manual){
            debug if(debug_channel.process) D.print("handling manual - Preprocess");
            let preProcessResponse =  switch(environment.onPreProcess){
              case(null) #DataNoOp;
              case(?envfunc) {
                switch(await* envfunc(pipeInstanceID, data, ?foundRequest, step)){
                  case(#trappable(val)) val;
                  case(#awaited(val)) val;
                  case(#err(#awaited(val))) #Error(val);
                  case(#err(#trappable(val))) #Error(val);
                };
              };
            };

            switch(preProcessResponse){
              case(#Error(err)) return #err(err);
              case(_){};
            };

            debug if(debug_channel.process) D.print("handling manual - process");
            let response : PipelineEventResponse = switch(environment.onProcess){
              case(null) #DataNoOp;
              case(?envfunc) {
                switch(await* envfunc(pipeInstanceID, data, ?foundRequest, step)){
                  case(#trappable(val)) val;
                  case(#awaited(val)) val;
                  case(#err(#awaited(val))) #Error(val);
                  case(#err(#trappable(val))) #Error(val);
                };
              };
            };
            
            //todo: handle response
            switch(response){
                case(#DataUpdated){
                    debug if(debug_channel.process) D.print("setting processedData");
                    //processedData := data.newData;
                    //todo...we are returing false so that the client can manually finalize
                    //todo probsbly need to calll on post prcess manually in the finalize function
                    return #ok{bFinished=false};
                };
                case(#StepNeeded){
                    debug if(debug_channel.process) D.print("more processing needed b");
                    return #ok{bFinished=false};
                };
                 case(#Error(err)){
                    debug if(debug_channel.process) D.print("Error occured" # debug_show(response));
                    return #err(err);
                };
                case(#Assigned(assignment)){

                };
                case(#DataNoOp){
                   debug if(debug_channel.process) D.print("setting noop");
                    //processedData := data.newData;
                    //todo...we are returing false so that the client can manually finalize
                    //todo probsbly need to calll on post prcess manually in the finalize function
                    return #ok{bFinished=false};
                };
            };

            debug if(debug_channel.process) D.print("handling manual - postProcess");
            let postProcessResponse = switch(environment.onPostProcess){
              case(null) #DataNoOp;
              case(?envfunc) {
                switch(await* envfunc(pipeInstanceID, data, ?foundRequest, step)){
                  case(#trappable(val)) val;
                  case(#awaited(val)) val;
                  case(#err(#awaited(val))) #Error(val);
                  case(#err(#trappable(val))) #Error(val);
                };
              };
            };
            switch(preProcessResponse){
              case(#Error(err)) return #err(err);
              case(_){};
            };

            return #ok({bFinished=true;});
        };
      };


      return #err({error_code =77777; message ="Not Implemented Execution Pathway"});
    };

    private func handleParallelProcessStepResult(pipeInstanceID : Nat, step: ?Nat, data : {data: CandyTypes.Workspace; bFinished: Bool}) : Bool{
      debug if(debug_channel.parallel) D.print("in parallel proces handling" # debug_show(data.bFinished));

      //more processing needed
      debug if(debug_channel.parallel) D.print("looking for cache");
      let ??cache = Map.get(state.processCache, Map.nhash, pipeInstanceID) else {
        if(data.bFinished == false){
          return true;
        };
        return false;
      };

      switch(step){
          case(?step){
              debug if(debug_channel.parallel) D.print("manipulating cache");
              cache.map[step] := true;
              cache.status := #Pending(step);
              return true;
          };
          case(null){
              //not implemented - a paralle process with unknown steps - shouldn't be here
              debug if(debug_channel.parallel) D.print("Hit not implemented parallel with unknown steps");

              return false;
          };
      };
      return false;
    };

    private func handleReturn(pipeInstanceID : Nat, finalData: CandyTypes.Workspace, request : ?ProcessRequest) : async* Result.Result<ProcessResponse,ProcessError> {

      let foundRequest = switch(request){
        case(null){
          switch(Map.get<Nat, ?RequestCache>(state.requestCache, Map.nhash, pipeInstanceID)){
            case(null){
              return #err({error_code=24; message = "cannot find request in cache"});
            };
            case(??val) val.request;
            case(?null){
              return #err({error_code=24; message = "cannot find request in cache"});
            };
          };
        };
        case(?val) val;
      };

      //ensure the item is removed from any processing queues
      ignore Set.remove<Nat>(state.pendingStepProcessing, Set.nhash, pipeInstanceID);

      let dataWillBeReturnedResponse = switch(environment.onDataWillBeReturned){
        case(null) #DataNoOp;
        case(?envfunc) {
          switch(await* envfunc(pipeInstanceID, finalData, ?foundRequest)){
            case(#trappable(val)) val;
            case(#awaited(val)) val;
            case(#err(#awaited(val))) #Error(val);
            case(#err(#trappable(val))) #Error(val);
          };
        };
      };

      switch(dataWillBeReturnedResponse){
        case(#Error(err)) return #err(err);
        case(_){};
      };


      switch(foundRequest.responseConfig){
          case(null){

            return #err({error_code=26; message = "Improperly configured response config"});
          };
          case(?#Include){
              debug if(debug_channel.returnData) D.print("returning the data");

              

              //todo: it is the calling library's responsibility to handle it if this is bigger than 2MB.
              let chunks = Workspace.getWorkspaceChunkSize(finalData, state.config.maxChunkSize);

              if(chunks > 1){
   
                let processResponse =
                    ?#OuttakeNeeded(?{
                        pipeInstanceID = pipeInstanceID;
                    });


                //todo: dilema: how do we return before we call onData Return!
                return #ok(processResponse);
              } else {

                Set.add<Nat>(state.pendingDataReturnedNotifications, Set.nhash, pipeInstanceID);


                let processResponse : ProcessResponse = ?#DataIncluded(?{
                    payload = Workspace.workspaceToAddressedChunkArray(finalData);
                });

                ignore Map.add<Nat, ?ResponseCache>(state.responseCache, Map.nhash, pipeInstanceID, ?{request = foundRequest; response = processResponse});

                if(state.processTimer == null){
                  state.processTimer := ?Timer.setTimer(#seconds(0), handleProcessTimer);
                };

                return #ok(processResponse);
              };
          };
          
          case(?#Pull(retriever)){
              debug if(debug_channel.returnData) D.print("waiting to return data");
              
              let processResponse =
              ?#OuttakeNeeded(?{
                  pipeInstanceID = pipeInstanceID;
              });

              ignore Map.add<Nat, ?ResponseCache>(state.responseCache, Map.nhash, pipeInstanceID, ?{request = foundRequest; response = processResponse});

              if(state.processTimer == null){
                state.processTimer := ?Timer.setTimer(#seconds(0), handleProcessTimer);
              };
              return #ok(processResponse);
          };

          case(?#Local(id)){
              debug if(debug_channel.returnData) D.print("returning data locally");

              switch(environment.putLocalWorkspace){
                case(null) {};
                case(?envfunc) {
                  ignore envfunc(pipeInstanceID, id, finalData, ?foundRequest);
                };
              };
              
              
              let processResponse =
                  ?#Local(id);
              
              
              ignore Map.add<Nat, ?ResponseCache>(state.responseCache, Map.nhash, pipeInstanceID, ?{request = foundRequest; response = processResponse});

              if(state.processTimer == null){
                state.processTimer := ?Timer.setTimer(#seconds(0), handleProcessTimer);
              };
              return #ok(processResponse);
          };
      

      };
      return #err({error_code=77777; message="Not Implemented Execution Pathway"});
    };

    private func handleProcessTimer() : async () {

      //todo realize this may get called multiple times
      state.processTimer := null;

      //handle calling any data returned calls.
      label dataReturnedNotifications for(pipeInstanceID in Set.keys<Nat>(state.pendingDataReturnedNotifications))  {
        
        let foundRequest = switch(Map.get<Nat, ?RequestCache>(state.requestCache, Map.nhash, pipeInstanceID)){
          case(??val) val.request;
          case(_){
            continue dataReturnedNotifications;
          };
        };


        let response = switch(Map.get<Nat, ?ResponseCache>(state.responseCache, Map.nhash, pipeInstanceID)){
          case(??val) val.response;
          case(_){
            continue dataReturnedNotifications;
          };
        };

        let dataReturnedResponse = switch(environment.onDataReturned){
          case(null) #DataNoOp;
          case(?envfunc) {
            switch(await* envfunc(pipeInstanceID, ?foundRequest, ?response)){
              case(#trappable(val)) val;
              case(#awaited(val)) val;
              case(#err(#awaited(val))) #Error(val);
              case(#err(#trappable(val))) #Error(val);
            };
          };
        };

        //todo: clean up?
        ignore Set.remove<Nat>(state.pendingDataReturnedNotifications, Set.nhash, pipeInstanceID);
      };

      //handle cleanUp for expired items.
      let currentTime = environment.getTime();
      switch(state.cleanUpTimer){
        case(?val){
          Timer.cancelTimer(val);
        };
        case(_){};
      };
      var tracker = 0;
      if(state.minExpiration < currentTime){
        label expired for(thisRequest in Map.entries(state.requestCache))  {
          let ?request = thisRequest.1 else continue expired;
          if(request.expiresAt < currentTime){
            tracker += 1;
            ignore Map.remove<Nat,?RequestCache>(state.requestCache, Map.nhash, thisRequest.0);
            ignore Map.remove<Nat,?ProcessCache>(state.processCache,  Map.nhash, thisRequest.0);
            ignore Map.remove<Nat,?ResponseCache>(state.responseCache,  Map.nhash, thisRequest.0);
            //ensure the item is removed from any processing queues
            ignore Set.remove<Nat>(state.pendingDataReturnedNotifications, Set.nhash, thisRequest.0);
            ignore Set.remove<Nat>(state.pendingStepProcessing, Set.nhash, thisRequest.0);

            if(tracker > state.config.maxClean){
              if(state.processTimer == null){
                state.processTimer := ?Timer.setTimer(#seconds(0), handleProcessTimer);
              };
              break expired;
            };
          } else {
            if(state.minExpiration > request.expiresAt){
              state.minExpiration := request.expiresAt;
            };
          };
        };
        //if we made it this far we need to set up a next expiration clean
        let timeUntilNextExpiration = state.minExpiration - currentTime;
        if(state.cleanUpTimer == null){
          state.cleanUpTimer := ?Timer.setTimer(#seconds((Int.abs(timeUntilNextExpiration) + 1000000000)/1000000000), handleProcessTimer);
        };
      };

      let service : MigrationTypes.Current.ProcessActor = actor(Principal.toText(environment.getCanister()));

      let futures = Vec.new<async Result.Result<ProcessResponse,ProcessError>>();

      //handle automatic processing steps
      label processingSteps for(pipeInstanceID in Set.keys<Nat>(state.pendingStepProcessing))  {

        let ?((thisCache, thisRequestCache)) = getWorkspaceAndRequestCache(pipeInstanceID) else continue processingSteps;

        let status : ProcessType = switch(environment.getProcessType){
          case(null) ?#Unconfigured;
          case(?envfunc) envfunc(pipeInstanceID, thisCache.data,?thisRequestCache.request);
        };

        switch(status){
          case(?#Unconfigured){
            //assume sequential
            Vec.add(futures, service.singleStep({pipeInstanceID = pipeInstanceID; step = null}));

          };
          case(?#Sequential(Nat)){
            Vec.add(futures, service.singleStep({pipeInstanceID = pipeInstanceID; step = null}));
          };
          case(?#Error(err)){
            continue processingSteps;
          };
          case(null){
            continue processingSteps;
          };
          case(?#Parallel(details)){
            var tracker = 0;
            for(thisStep in details.stepMap.vals()){
              if(thisStep == false){
                Vec.add(futures, service.singleStep({pipeInstanceID = pipeInstanceID; step = ?tracker}));
              };
              tracker += 1;
              if(Vec.size(futures) >= state.config.maxParallelSteps){
                break processingSteps;
              };
            };
            
          };
          
        };
        if(Vec.size(futures) >= state.config.maxParallelSteps){
          break processingSteps;
        };
      };
    };

    private func getWorkspaceAndRequestCache(pipeInstanceID : Nat) : ?(WorkspaceCache, RequestCache) {

      let ??thisCache = Map.get(state.workspaceCache, Map.nhash, pipeInstanceID) else return null;

      let ??thisRequestCache = Map.get(state.requestCache, Map.nhash, pipeInstanceID) else return null;

      return ?(thisCache, thisRequestCache);
    };


    public func singleStep(request : StepRequest) : async* Result.Result<ProcessResponse, ProcessError> {
      //process the data
      let ?((thisCache, thisRequestCache)) = getWorkspaceAndRequestCache(request.pipeInstanceID) else return #err({error_code = 27; message = "Cannot find Cache " # debug_show(request.pipeInstanceID)});

      debug if(debug_channel.singleStep) D.print("In single step pipelinify " # debug_show(request));


      debug if(debug_channel.singleStep) D.print("processing final chunks " # debug_show(SB.size(thisCache.data)));

      let processingResult = await* handleProcessing(request.pipeInstanceID, thisCache.data, ?thisRequestCache.request, request.step);

      switch(processingResult){
          case(#ok(data)){
               debug if(debug_channel.singleStep) D.print("handling single step process");

              //processedData := data;
              let notFinished : Bool = handleParallelProcessStepResult(request.pipeInstanceID, request.step, {bFinished = data.bFinished; data= thisCache.data});
                  //more processing needed
 
              let status : ProcessType = switch(environment.getProcessType){
                case(null) ?#Unconfigured;
                case(?envfunc) envfunc(request.pipeInstanceID, thisCache.data,?thisRequestCache.request);
              };

              switch(status){
                  //let user finalize for parallel
                  case(?#Parallel(info)){
                       debug if(debug_channel.singleStep) D.print("inside of the more steps handler");
                      return #ok(?#StepProcess(?{
                          pipeInstanceID = request.pipeInstanceID;
                          status = status;
                      }));
                  };
                  case(?#Sequential(info)){
                      if(data.bFinished == true){
                          //do nothing
                      } else {
                          return #ok(?#StepProcess(?{
                          pipeInstanceID = request.pipeInstanceID;
                          status = status;
                      }));
                      };
                  };
                  case(_){
                      return #err({error_code=948484; message="not configured"});
                  }
              }
          };
          case(#err(theError)){
              return #err(theError);
          }
      };


      //return the data
      debug if(debug_channel.singleStep) D.print("should only be here for sequential - return after single step");

      return await* handleReturn(request.pipeInstanceID, thisCache.data, ?thisRequestCache.request);
    };

    public func getPushStatus(request : PushStatusRequest) : Result.Result<ProcessResponse, ProcessError> {
      let ?((thisCache, thisRequestCache)) = getWorkspaceAndRequestCache(request.pipeInstanceID) else return #err({error_code = 27; message = "Cannot find Cache " # debug_show(request.pipeInstanceID)});

 
      switch(thisCache.status){
          case(?#Initialized){
              return #ok(?#IntakeNeeded(?{
                          pipeInstanceID = request.pipeInstanceID;
                          currentChunks = 0;
                          totalChunks = 0;
                          chunkMap = [];
                      }));
          };
          case(?#DoneLoading){
            return #ok(?#StepProcess(?{
              pipeInstanceID = request.pipeInstanceID;
              status = switch(environment.getProcessType){
                case(null) ?#Unconfigured;
                case(?envfunc) envfunc(request.pipeInstanceID, thisCache.data,?thisRequestCache.request);
              };
            }))};
          case(?#Loading(?chunkData)){
              return #ok(?#IntakeNeeded(?{
                pipeInstanceID = request.pipeInstanceID;
                currentChunks = chunkData.processedChunks;
                totalChunks = chunkData.totalChunks;
                chunkMap = Array.freeze<Bool>(chunkData.recievedItemMap);
              }));
          };
          case(_){
            return #err({error_code=15; message="done loading"});
          };
      };
    };

    public func pushChunk(caller: ?Principal, request : ChunkPush) : async Result.Result<ProcessResponse, ProcessError> {

       debug if(debug_channel.announce) D.print("in push chunk");

      // pull the intake cache
      let ?(thisCache, thisRequest)  = getWorkspaceAndRequestCache(request.pipeInstanceID) else return #err({error_code = 27; message = "Cannot find Cache " # debug_show(request.pipeInstanceID)});

      //check permissions
      let chunkInfo = switch(thisRequest.request.dataConfig){
        
        case(?#Push(?detail)){
          if(detail.permission != null and caller != detail.permission){
            return #err({error_code = 29; message = "Unauthorized " # debug_show(detail)});
          };
          detail;
        };
        case(?#Push(_)){
          return #err({error_code = 30; message = "Misconfigured Push " # debug_show(thisRequest.request.dataConfig)});
        };
        case(_){
          return #err({error_code = 30; message = "Not a push type " # debug_show(thisRequest.request.dataConfig)});
        };
      };

      //prepare the new cache entry
      switch(thisCache.status){
          case(?#DoneLoading){return #err({error_code=15; message="done loading";})};
          case(?#Processing(val)){return #err({error_code=15; message="done loading";})};
          case(?#DoneProcessing){return #err({error_code=15; message="done loading";})};
          case(?#Done){return #err({error_code=15; message="done loading";})};
          case(_){
              //keep going
              debug if(debug_channel.push) D.print("keep going");
          };
      };
        

      switch(thisCache.status){
          case(?#Initialized){
              debug if(debug_channel.push) D.print("in parallel initialized" # debug_show(chunkInfo));
              let thisMap = Array.init<Bool>(chunkInfo.totalChunks, false);
              if(request.chunk.index >= thisMap.size()){
                return #err({error_code=31; message="index out of bounds " # debug_show(request.chunk.index);})
              };
              thisMap[request.chunk.index] := true;
              
              Workspace.fileAddressedChunks(thisCache.data, request.chunk.data);

              if(chunkInfo.totalChunks == 1){
                thisCache.status := ?#DoneLoading;
              } else {
                thisCache.status := ?#Loading(?{
                  var processedChunks = 1;
                  totalChunks = chunkInfo.totalChunks;
                  recievedItemMap = thisMap;
                });
              };
          };
          case(?#Loading(?loadingVal)){
              debug if(debug_channel.push) D.print("in prallel loading");
              if(request.chunk.index < loadingVal.recievedItemMap.size()){
                return #err({error_code=31; message="index out of bounds";})
              };

              if(loadingVal.recievedItemMap[request.chunk.index] == true){
                return #err({error_code=32; message="already revieved chunk";})
              };
              loadingVal.recievedItemMap[request.chunk.index] := true;
              loadingVal.processedChunks += 1;

              Workspace.fileAddressedChunks(thisCache.data, request.chunk.data);
              debug if(debug_channel.push) D.print("map is " # debug_show(loadingVal.recievedItemMap));

              //decide if we are finished pushing
              var finished = true;
              label search for(thisItem in loadingVal.recievedItemMap.vals()){
                if(thisItem == false){
                  finished := false;
                  break search;
                };

              };

              if(finished){
                thisCache.status := ?#DoneLoading;
              };
          };
          case(_){
              //todo: need to handle errors
              //throw #err({text="Cannot add to intake cached for a 'done' intake cache"; code = 9;});
              debug if(debug_channel.push) D.print("error...already loaded");
              return #err({error_code = 14; message="pipe already pushed"});
          };

      };


      //load the data into the cache
      //todo: maybe only if not done?
      //Debug.print("Putting the intake cache.");
      //intakeCache.put(request.pipeInstanceID, newCache);


      switch(thisCache.status){
          case(?#Initialized){
              return #err({message="Unloaded Intake Cache. Should Not Be Here."; error_code = 11;})
          };
          case(?#Loading(?loadingValue)){
              //we are done and will hang out until the next cache push
              debug if(debug_channel.push) D.print("Done...hanging out for more push.");
              return #ok(?#IntakeNeeded(?{
                  pipeInstanceID = request.pipeInstanceID;
                  currentChunks = loadingValue.processedChunks;
                  totalChunks = loadingValue.totalChunks;
                  chunkMap = Array.freeze<Bool>(loadingValue.recievedItemMap);
              }));
          };
          case(?#DoneLoading){
            //we need to look at the execution config
            debug if(debug_channel.push) D.print("we uploaded a chunk and now we are done" # debug_show(thisRequest.request.executionConfig));
             
            switch(thisRequest.request.executionConfig){
              case(?#OnLoad){
                  //we are going to run the process now

                  debug if(debug_channel.push) D.print("have final data chunks");
                  //var finalData = Array.flatten<Nat8>(newCache.data);
                  //Debug.print("have final data " # debug_show(finalData.size()));

                  let processingResult = await* handleProcessing(request.pipeInstanceID, thisCache.data, ?thisRequest.request, null);

                  debug if(debug_channel.push) D.print("got the results " # debug_show(processingResult));
                  switch(processingResult){
                      case(#ok(data)){
                          debug if(debug_channel.push) D.print("got back from the handle process");
                          if(handleParallelProcessStepResult(request.pipeInstanceID, null, {bFinished = data.bFinished; data = thisCache.data}) == true){
                              //more processing needed

                              return #ok(?#StepProcess(?{
                                  pipeInstanceID = request.pipeInstanceID;
                                  status  = switch(environment.getProcessType){
                                    case(null) ?#Unconfigured;
                                    case(?envfunc) envfunc(request.pipeInstanceID, thisCache.data,?thisRequest.request);
                                  };
                              }));
                          };
                          //processedData := data;
                      };
                      case(#err(theError)){

                          debug if(debug_channel.push) D.print("I don't like that im here" );
                          return #err(theError);
                      }
                  };

                  return await* handleReturn(request.pipeInstanceID, thisCache.data, ?thisRequest.request);

              };
              case(?#Manual){
                  return #ok(?#StepProcess(?{
                      pipeInstanceID = request.pipeInstanceID;
                      status = switch(environment.getProcessType){
                        case(null) ?#Unconfigured;
                        case(?envfunc) envfunc(request.pipeInstanceID, thisCache.data,?thisRequest.request);
                      };
                  }));
              };
              case(null){
                return #err({message="Execution config missing."; error_code = 32;})
              };
            };

          };
          case(_){
              debug if(debug_channel.push) D.print("didnt handle status");
          }
      };
  
      return #err({message="Not Implemented"; error_code = 984585;});
    };


    public func getProcessingStatus(request : ProcessingStatusRequest) : Result.Result<ProcessResponse, ProcessError> {

      // pull the intake cache
      let ?(thisCache, thisRequest)  = getWorkspaceAndRequestCache(request.pipeInstanceID) else return #err({error_code = 27; message = "Cannot find Cache " # debug_show(request.pipeInstanceID)});

      let processType = switch(environment.getProcessType){
        case(null) ?#Unconfigured;
        case(?envfunc) envfunc(request.pipeInstanceID, thisCache.data,?thisRequest.request);
      };

      switch(thisCache.status){
          case(?#Initialized){
              return #err({error_code=21; message="processing not ready"});
          };
          case(?#Loading(?someData)){
              if(someData.recievedItemMap.size() > 0){
                  let total = someData.recievedItemMap.size();
                  var tracker = 0;
                  for(thisItem in someData.recievedItemMap.vals()){
                      if(thisItem == true){
                          tracker += 1;
                      };
                  };
                  if(tracker < total){
                      return #err({error_code=21; message="processing not ready"});
                  } else {
                      return #ok(?#StepProcess(?{
                          pipeInstanceID = request.pipeInstanceID;
                          status = processType;
                      }));
                  };
              };

              return #err({error_code=21; message="processing not ready"});
          };

          case(?#DoneLoading){
              return #ok(?#StepProcess(?{
                  pipeInstanceID = request.pipeInstanceID;
                  status =processType;
              }))};
          case(?#Processing(chunkData)){
              return #ok(?#StepProcess(?{
                  pipeInstanceID = request.pipeInstanceID;
                  status = processType;
              }))};

          case(?#DoneProcessing){
              return #ok(?#OuttakeNeeded(?{
              pipeInstanceID = request.pipeInstanceID;
              //todo: add outtake status
          }))};

          case(_){
              return #err({error_code=22; message="done loading"});
          }
      };
    };

    public func getChunk(caller : ?Principal, request : ChunkGet) : Result.Result<ChunkResponse, ProcessError> {

      // pull the intake cache
      debug if(debug_channel.pull) D.print("made it to get chunk");

      // pull the intake cache
      let ?(thisCache, thisRequest)  = getWorkspaceAndRequestCache(request.pipeInstanceID) else return #err({error_code = 27; message = "Cannot find Cache " # debug_show(request.pipeInstanceID)});

      let chunkInfo = switch(thisRequest.request.responseConfig){
        
        case(?#Pull(?detail)){
          if(detail.permission != null and caller != detail.permission){
            return #err({error_code = 29; message = "Unauthorized " # debug_show(detail)});
          };
          detail;
        };
        case(?#Include){
          {
            totalChunks = Workspace.getWorkspaceChunkSize(thisCache.data, request.chunkSize);
            permission = null;
          };
        };
        case(?#Local(index)){
          //load the workspace from the local environment
          let thisWorkspace = switch(environment.getLocalWorkspace){
            case(?envfunc) envfunc(request.pipeInstanceID, index, ?thisRequest.request);
            case(null) Workspace.emptyWorkspace();
          };
          {
            totalChunks = Workspace.getWorkspaceChunkSize(thisWorkspace,request.chunkSize);
            permission = null;
          };
        };
        case(_){
          return #err({error_code = 30; message = "Not a pull type " # debug_show(thisRequest.request.dataConfig)});
        };
      };

      let result = Workspace.getWorkspaceChunk(thisCache.data, request.chunkID, request.chunkSize);

      let totalSize = Workspace.getWorkspaceChunkSize(thisCache.data, request.chunkSize);
      
        
      return #ok(#Chunk({chunk = {
        data = SB.toArray(result.1); index = request.chunkID}; 
        totalChunks = totalSize}));


      //call process if necessary
      return #err({message="Not Implemented"; error_code = 984585;});

    };

    public func getRequests() : Result.Result<[?RequestCache], ProcessError> {


      return #ok(Iter.toArray<?RequestCache>(Map.vals<Nat,?RequestCache>(state.requestCache)));

    };

  };
};