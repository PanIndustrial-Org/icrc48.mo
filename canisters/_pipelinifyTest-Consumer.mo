

import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Pipelinify "../src/processor";
import PipelinifyTypes "../src/migrations/types";
import Principal "mo:base/Principal";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Nat8 "mo:base/Nat8";
import Text "mo:base/Text";
import Processor "_pipelinifyTest-Processor";


shared (install) actor class Consumer() = this {

    type Result<T,E> = Result.Result<T,E>;

    //var nonce : Nat = 0;

    type Hash = Hash.Hash;
    //let thisPrincipal : Principal = Principal.fromActor(this);
    //let thisChunkHandler : PipelinifyTypes.Current.DataSource = this;

    let processor : Processor.Processor = actor("bd3sg-teaaa-aaaaa-qaaba-cai");


    public func testFullDataSendProcess(_starterArray: [Pipelinify.CandyTypes.AddressedChunk]) : async [Pipelinify.CandyTypes.AddressedChunk] {


        Debug.print("==========testFullDataSendProcess==========");




        let response = await processor.process({
            caller = ?Principal.fromActor(this);
            createdAt = Time.now();
            expiresAt = null;
            event = ?"dataIncludedTest";
            dataConfig = ?#DataIncluded{
                data : [Pipelinify.CandyTypes.AddressedChunk] = _starterArray;

            };
            executionConfig = ?#OnLoad;
            responseConfig = ?#Include;
            processConfig = null;
        });

        switch(response){
            case(#ok(data)){
                switch(data){
                    case(?#DataIncluded(?details)){
                        return details.payload;
                    };
                    case(_){
                        return [];
                    };
                };
            };
            case(_){
                return [];
            };
        };


        return [];
    };

    public func testPushFullResponse() : async [Pipelinify.CandyTypes.AddressedChunk] {


        Debug.print("==========testPushFullResponse==========");

        let response = await processor.process({
            caller = ?Principal.fromActor(this);
            createdAt = Time.now();
            expiresAt = null;
            event = ?"dataPush";
            dataConfig = ?#Push(?{permission = null; totalChunks = 1});
            executionConfig = ?#OnLoad;
            responseConfig = ?#Pull(?{permission = null;});
            processConfig = null;
        });

        Debug.print(debug_show(response));
        switch(response){
            case(#err(errType)){
                return [];
            };
            case(#ok(responseType)){
                switch(responseType){
                    case(?#IntakeNeeded(?result)){
                        Debug.print("Intake needed");
                        let pushFullResponse = await processor.pushChunk({
                            pipeInstanceID = result.pipeInstanceID;
                            chunk = {data =[(0,0,#Bytes([10:Nat8,9:Nat8,8:Nat8,7:Nat8]))]; index=0;}});

                        Debug.print("got a response from the push");
                        Debug.print(debug_show(pushFullResponse));

                        switch(pushFullResponse){
                            case(#ok(?#OuttakeNeeded(?details))){
                                Debug.print("getting chunk from outtake");
                                let pushFullResponse = switch(await processor.getChunk({
                                    pipeInstanceID = details.pipeInstanceID;
                                    chunkID = 0;
                                    chunkSize=2000000})
                                ){
                                  case(#ok(#Chunk(chunkdata))){
                                    Debug.print("returning a chunk");
                                    return chunkdata.chunk.data;
                                  };
                                  case(_){
                                    return [];
                                  }
                                };
                            };

                            case(#ok(?#DataIncluded(?details))){
                              return details.payload;
                            };
                            case(_){
                                return [];
                            };
                        };
                    };
                    case(_){
                        Debug.print("Did not find intake needed");
                        return [];
                    };
                };

            };
        };




        return [];
    };

};