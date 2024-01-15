// please do not import any types from your project outside migrations folder here
// it can lead to bugs when you change those types later, because migration types should not be changed
// you should also avoid importing these types anywhere in your project directly from here
// use MigrationTypes.Current property instead

import D "mo:base/Debug";
import Blob "mo:base/Blob";
import Order "mo:base/Order";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Option "mo:base/Option";
import Deque "mo:base/Deque";
import Nat "mo:base/Nat";
import StarLib "mo:star/star";

import MapLib "mo:map9/Map";
import SetLib "mo:map9/Set";
import VecLib "mo:vector";
import CandyTypesLib "mo:candy/types";
import CandyWorkspaceLib "mo:candy/workspace";
import SBLib "mo:stablebuffer_1_3_0/StableBuffer";

module {

  /// Vector provides an interface to a vector-like collection.
  public let Vector = VecLib;

  /// Map provides an interface to a key-value storage collection.
  public let Map = MapLib;

  /// Set provides an interface to a set-like collection, storing unique elements.
  public let Set = SetLib;

  public let SB = SBLib;

  public let Star = StarLib;

  public let CandyTypes = CandyTypesLib;
  public let Workspace = CandyWorkspaceLib;
  

  public type PipeInstanceID = Nat;
  public type Value = CandyTypes.ValueShared;

  public type ChunkGet = {
    chunkID: Nat;
    chunkSize: Nat;
    pipeInstanceID: PipeInstanceID;
  };

  public type ChunkRequest = {
    chunkID: Nat;
    event: ?Text;
    sourceIdentifier: ?Nat;
  };

  public type ChunkDetail = {
      data : [CandyTypes.AddressedChunk];
      index : Nat
    };

  public type ChunkResponse = {
    #Chunk: {
      chunk : ChunkDetail;
      totalChunks : Nat;
    };
    #Error: ProcessError;
  };

  public type ChunkPush = {
    pipeInstanceID: PipeInstanceID;
    chunk: ChunkDetail;
  };

  public type ProcessError = {
    message: Text;
    error_code: Nat;
  };

  // Let's a process requestor to tell the processing server how to retrieve the data needed for processing
  public type DataConfig  = {
      #DataIncluded : {
          data: [CandyTypes.AddressedChunk]; //data if small enough to fit in the message
      };
      #Local : Nat;
      #Push : ?{
        permission: ?Principal;
        totalChunks: Nat;
      };
      #Internal;
  };

  public type DataSource = actor {
    requestPipelinifyChunk : (_request : ChunkRequest) -> async Result.Result<ChunkResponse,ProcessError>;
    queryPipelinifyChunk : query (_request : ChunkRequest) -> async Result.Result<ChunkResponse,ProcessError>;
  };

  public type ProcessRequest = {
    event: ?Text;  //User may provide an event namespace
    caller: ?Principal;
    expiresAt : ?Int;
    dataConfig: ?DataConfig;
    executionConfig: ?ExecutionConfig;
    responseConfig: ?ResponseConfig;
    createdAt: Int; //deduplication
  };

  public type ResponseConfig = {
      #Include;
      #Pull : ?{
        permission: ?Principal;
      };
      #Local : Nat;
  };

  public type ExecutionConfig = {
    #OnLoad;
    #Manual;
  };

  public type ProcessResponse = ?{
    #DataIncluded: ?{
        payload: [CandyTypes.AddressedChunk];
    };
    #Local : Nat;
    #IntakeNeeded: ?{
        pipeInstanceID: PipeInstanceID;
        currentChunks: Nat;
        totalChunks: Nat;
        chunkMap: [Bool];
    };
    #OuttakeNeeded: ?{
        pipeInstanceID: PipeInstanceID;
    };
    #StepProcess: ?{
        pipeInstanceID: PipeInstanceID;
        status: ProcessType;
    };
    #Assigned: {
      pipeInstanceID: PipeInstanceID;
      canister:Principal; //this process has been assigned to another server for processing.
    };
  };

  public type ProcessType = ?{
    #Unconfigured;
    #Error;
    #Sequential: Nat;
    #Parallel: {
        stepMap: [Bool];
        steps: Nat;
    };
  };

  public type PushStatusRequest = {
    pipeInstanceID: PipeInstanceID;
  };

  public type ProcessingStatusRequest = {
    pipeInstanceID: PipeInstanceID;
  };

  public type StepRequest = {
    pipeInstanceID: PipeInstanceID;
    step: ?Nat;
  };

  public type WorkspaceCache = {
    var status : ?{
        #Initialized;
        #Loading : ?{
          var processedChunks : Nat;
          totalChunks : Nat;
          recievedItemMap : [var Bool];
        };
        #DoneLoading;
        #Processing: Nat;
        #DoneProcessing;
        #Assigned: Principal;
        #Done
    };
    data: CandyTypes.Workspace;
  };

  public type RequestCache = {
    request : ProcessRequest;
    timestamp : Int;
    expiresAt : Int;
    status: {
      #Initialized;
      #DataDone;
      #ResponseReady;
      #Finalized;
    };
  };

  public type ResponseCache = {
    request : ProcessRequest;
    response: ProcessResponse;
  };

  public type ProcessCache = {
    map : [var Bool];
    steps : Nat;
    var status: {
      #Initialized;
      #Done;
      #Pending: Nat;
    };
  };

  public type ProcessActor = actor {
      process : (_request : ProcessRequest) -> async Result.Result<ProcessResponse,ProcessError>;
      getChunk : (_request : ChunkGet) -> async Result.Result<ChunkResponse, ProcessError>;
      pushChunk: (_request: ChunkPush) -> async Result.Result<ProcessResponse, ProcessError>;
      getPushStatus: query (_request: PushStatusRequest) -> async Result.Result<ProcessResponse, ProcessError>;
      getProcessingStatus: query (_request: ProcessingStatusRequest) -> async Result.Result<ProcessResponse,ProcessError>;
      singleStep: (_request: StepRequest) -> async Result.Result<ProcessResponse,ProcessError>;
  };

  public type PipelineEventResponse = {
    #DataNoOp;
    #DataUpdated;
    #StepNeeded;
    #Assigned: Principal;
    #Error : ProcessError;
  };

  public let defaultTimeOut : Int = 120_000_000_000;
  public let THEFUTURE : Int = 33261830882000000000;

  public type Environment = {
    getTime : () -> Int;
    getCanister : () -> Principal;
    addLedgerTransaction : ?((Value, ?Value) -> Nat); //called when a transaction needs to be added to the ledger.  Used to provide compatibility with ICRC3 based transaction logs. When used in conjunction with ICRC3.mo you will get an ICRC3 compatible transaction log complete with self archiving.
    onDataWillBeLoaded : ?((PipeInstanceID, ?ProcessRequest) -> async* Star.Star<PipelineEventResponse, ProcessError>);
    onDataReady : ?((PipeInstanceID, CandyTypes.Workspace, ?ProcessRequest) -> async* Star.Star<PipelineEventResponse, ProcessError>);
    onPreProcess : ?((PipeInstanceID, CandyTypes.Workspace, ?ProcessRequest, ?Nat) -> async* Star.Star<PipelineEventResponse, ProcessError>);
    onProcess : ?((PipeInstanceID, CandyTypes.Workspace, ?ProcessRequest, ?Nat) -> async* Star.Star<PipelineEventResponse, ProcessError>);
    onPostProcess : ?((PipeInstanceID, CandyTypes.Workspace, ?ProcessRequest, ?Nat) -> async* Star.Star<PipelineEventResponse, ProcessError>);
    onDataWillBeReturned : ?((PipeInstanceID, CandyTypes.Workspace, ?ProcessRequest,) -> async* Star.Star<PipelineEventResponse, ProcessError>);
    onDataReturned : ?((PipeInstanceID, ?ProcessRequest, ?ProcessResponse) -> async* Star.Star<PipelineEventResponse, ProcessError>);
    getProcessType : ?((PipeInstanceID, CandyTypes.Workspace, ?ProcessRequest) -> ProcessType);
    putLocalWorkspace : ?((PipeInstanceID, Nat, CandyTypes.Workspace, ?ProcessRequest) -> CandyTypes.Workspace);
    getLocalWorkspace : ?((PipeInstanceID, Nat, ?ProcessRequest) -> CandyTypes.Workspace);

  };

  public type InitArgs = {
    defaultTimeOut : ?Int;
    advancedSettings : ?{
      existingWorkspaceCache: [(Nat, ?WorkspaceCache)];
      existingRequestCache: [(Nat, ?RequestCache)];
      existingProcessCache : [(Nat, ?ProcessCache)];
      existingResponseCache : [(Nat, ?ResponseCache)];
      existingNonce : Nat;
      existingDataReturnedNotifications: [Nat];
      existingStepProcessing: [Nat]
    };
  };

  public type Stats = {
    nonce: Nat;
    workspaceCount : Nat;
    requestCount: Nat;
    processCount: Nat;
    responseCount: Nat;
    pendingDataReturnedNotifications : Nat;
    pendingStepProcessing : Nat;
    processTimer: ?Nat;
    cleanUpTimer: ?Nat;
    config: {
      defaultTimeOut : Int;
      maxClean : Nat;
      maxParallelSteps: Nat;
      maxChunkSize : Nat;
    };
  };

  public type State = {
    var nonce : Nat;
    var minExpiration : Int;
    var workspaceCache : Map.Map<Nat, ?WorkspaceCache>;
    var requestCache : Map.Map<Nat, ?RequestCache>;
    var processCache : Map.Map<Nat, ?ProcessCache>;
    var responseCache : Map.Map<Nat, ?ResponseCache>;
    var pendingDataReturnedNotifications: Set.Set<Nat>;
    var pendingStepProcessing: Set.Set<Nat>;
    var processTimer : ?Nat;
    var cleanUpTimer : ?Nat;
    config : {
      var defaultTimeOut : Int;
      var maxClean : Nat;
      var maxParallelSteps : Nat;
      var maxChunkSize : Nat;
    };
  };



}