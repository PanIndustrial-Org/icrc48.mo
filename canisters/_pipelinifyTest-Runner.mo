

import Array "mo:base/Array";
import Nat "mo:base/Nat";
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
import Consumer "_pipelinifyTest-Consumer";

actor class pipelinify_runner(){
    type Result<T,E> = Result.Result<T,E>;

    var nonce : Nat = 0;

    type Hash = Hash.Hash;

    public func Test() : async Result<Text, Text>{
        /////////////////////////
        //      Data Load Test
        //        fullData - ✓ - Makes a request of the consumer, consuemer sends all data to the processor and gets a response.
        //        pullData(at Once) - ✓ - Makes a request of the consumer, consumer asks the processor to pull the data and then process
        //        pullData(chunks) - ✓ - Makes a request of the consumer, consumer asks the processor to pull 7 remaining chunks and then process
        //        pullDataUnkownNumberOfChunks - ✓ - Makes a request of the consumer, consumer asks the processor to pull remaining chunks ..consumer must respond with eof, and then processor process
        //        pullDataQuery ✓ - Makes a request of the consumer, consumer asks the processor to pull remaining chunks via query...uses same pathway as pull but switches to query
        //        push(delayed at once)  | push(chunks)
        //
        //           Execution Tests
        //           onLoad    |  selfServe(at once) | selfServe(step)  |  still processing  | aget(at once) | agent(step)
        //
        //           Data Retrieval Tests
        //           included  |  pullData(at once)  |  pullData(steps)  | pullDataQuery  |
        //////////////////////////

        var testStream : Text = "Running Tests \n";
        let consumer : Consumer.Consumer = actor("bkyz2-fmaaa-aaaaa-qaaaq-cai");


        ////////
        //Full Data Test
        ////////

        testStream #= "Testing Full Data Send - ";

        let testFullDataSendResponse = await consumer.testFullDataSendProcess([(0,0,#Bytes([0,1,2,3]))]);
        let tester5 = Conversion.candySharedToBytes(testFullDataSendResponse[0].2);

        if(tester5[0] == 4 and tester5[1] == 5 and tester5[2] == 6 and tester5[3] == 7){
            testStream #= "✓\n";
        }
        else{
            testStream #= "x\n";
            testStream #= "Expected " # debug_show(testFullDataSendResponse) # " to be [4,5,6,7]";
        };

        ////////
        //Push Full Data
        ////////
        testStream #= "Testing Push Data - Full - ";

        let testPushFullResponse = await consumer.testPushFullResponse();
        let tester = Conversion.candySharedToBytes(testPushFullResponse[0].2);

        if(tester[0] == 5 and tester[1] == 4 and tester[2] == 3 and tester[3] == 2){
            testStream #= "✓\n";
        }
        else{
            testStream #= "x\n";
            testStream #= "Expected " # debug_show(testPushFullResponse) # " to be [5,4,3,2]";
        };

        return #ok(testStream);

    };


};
