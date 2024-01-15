

import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Pipelinify "../src/processor";
import PipelinifyTypes "../src/migrations/types";
import Candy "mo:candy/types";
import Conversion "mo:candy/conversion";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Nat8 "mo:base/Nat8";
import SB "mo:stablebuffer_1_3_0/StableBuffer";

actor class Processor() = this {
    let processor = Principal.fromText("bd3sg-teaaa-aaaaa-qaaba-cai");

    type Result<T,E> = Result.Result<T,E>;

    var nonce : Nat = 0;

    type Hash = Hash.Hash;
    let CandyTypes = Pipelinify.CandyTypes;

    func onProcess(_hash : Nat, _data : PipelinifyTypes.Current.CandyTypes.Workspace, _processRequest : ?PipelinifyTypes.Current.ProcessRequest, _step : ?Nat) : async* Pipelinify.Star.Star<PipelinifyTypes.Current.PipelineEventResponse, PipelinifyTypes.Current.ProcessError> {

        //Debug.print("processing chunk" # debug_show(_processRequest));
        switch(_processRequest){
            case(?_processRequest){


                switch(_processRequest.dataConfig, _processRequest.event){
                    case(?#DataIncluded(data), ?event){
                        if(event == "dataIncludedTest"){
                            Debug.print("In the test" # debug_show(data));
                            //Debug.print(debug_show( _data.get(0).get(0).toArray()));
                            if(Array.equal([0:Nat8,1:Nat8,2:Nat8,3:Nat8], Conversion.candyToBytes(SB.get<CandyTypes.DataChunk>(SB.get<CandyTypes.DataZone>(_data,0),0)), Nat8.equal)){
                                Debug.print("Array matched, processing");
                                 let byteBuffer = SB.get<CandyTypes.DataChunk>(SB.get<CandyTypes.DataZone>(_data,0),0);

                                 switch(byteBuffer){
                                  case(#Bytes(val)){
                                    SB.put<Nat8>(val, 0, 4);
                                    SB.put<Nat8>(val, 1, 5);
                                    SB.put<Nat8>(val, 2, 6);
                                    SB.put<Nat8>(val, 3, 7);
                                  };
                                  case(_){
                                    return #err(#trappable({message = "Not Implemented"; error_code = 99999}));
                                  };
                                 };
                                
                                Debug.print("done updating");
                                return #trappable(#DataUpdated);
                            } else {
                                //Debug.print(debug_show( _data.get(0).get(0).toArray()));
                                return #err(#trappable({message = "Not Implemented"; error_code = 99999}));
                            };
                        };

                    };
                    
                    case(?#Push(config), ?event){
                        if (event == "dataPush") {
                            //Debug.print("should have data" # debug_show(_data.get(0).get(0)));
                            if(Array.equal([10:Nat8,9:Nat8,8:Nat8,7:Nat8], Conversion.candyToBytes(SB.get<CandyTypes.DataChunk>(SB.get<CandyTypes.DataZone>(_data,0),0)), Nat8.equal)){
                               let byteBuffer = SB.get<CandyTypes.DataChunk>(SB.get<CandyTypes.DataZone>(_data,0),0);

                                 switch(byteBuffer){
                                  case(#Bytes(val)){
                                    SB.put<Nat8>(val, 0, 5);
                                    SB.put<Nat8>(val, 1, 4);
                                    SB.put<Nat8>(val, 2, 3);
                                    SB.put<Nat8>(val, 3, 2);
                                  };
                                  case(_){
                                    return #err(#trappable({message = "Not Implemented"; error_code = 99999}));
                                  };
                                 };
                                return #trappable(#DataUpdated);
                            } else {
                                return #err(#trappable({message = "Not Implemented"; error_code = 99999}));
                            };
                        };
                    };

                    case(_, _){
                        return #err(#trappable({message = "Not Implemented"; error_code = 99999}));
                    }
                };

            };
            case(null){
                return #err(#trappable({message = "process request null"; error_code = 999991}));
            };
        };

        return #err(#trappable({message = "process request null"; error_code = 999991}));
    };


    let pipelinify_state = Pipelinify.init(Pipelinify.initialState(), #v0_1_0(#id),?{
            defaultTimeOut = null;
            advancedSettings = null;
        }, processor);

    let pipelinify = Pipelinify.ICRC48(?pipelinify_state, processor, {
        getTime = Time.now;
        onDataWillBeLoaded = null;
        onDataReady = null;
        onPreProcess = null;
        onProcess = ?onProcess;
        onPostProcess = null;
        onDataWillBeReturned = null;
        onDataReturned = null;
        getProcessType = null;
        getLocalWorkspace = null;
        putLocalWorkspace = null;
        addLedgerTransaction = null;
        getCanister = func(): Principal {return processor};
    });


    public func process(_request : PipelinifyTypes.Current.ProcessRequest) : async Result<PipelinifyTypes.Current.ProcessResponse, PipelinifyTypes.Current.ProcessError>{
       return await pipelinify.process(_request);
    };

    public func pushChunk(_chunk : PipelinifyTypes.Current.ChunkPush) : async Result<PipelinifyTypes.Current.ProcessResponse, PipelinifyTypes.Current.ProcessError>{
       return await pipelinify.pushChunk(?Principal.fromActor(this), {pipeInstanceID = _chunk.pipeInstanceID; chunk = _chunk.chunk;});
    };

     public func getChunk(_chunk : PipelinifyTypes.Current.ChunkGet) : async Result<PipelinifyTypes.Current.ChunkResponse, PipelinifyTypes.Current.ProcessError>{
       return pipelinify.getChunk(?Principal.fromActor(this), _chunk);
    };
};
