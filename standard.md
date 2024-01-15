
### Abstract

The proposed Internet Computer Request for Comment (ICRC) introduces a comprehensive standard for processing workloads between canisters on the DFINITY Internet Computer platform. This standard delineates a robust, scalable workflow enabling users to submit processing requests to a canister, upload data for processing, and subsequently retrieve the results. The proposal lays out a structured approach for managing and transferring data in a distributed canister environment, focusing on efficient data handling, scalability, and interoperability among diverse canisters.

This ICRC standard, with its detailed specification of types, methods, and data flow, aims to establish a common framework that fosters seamless interaction between canisters, enhancing the overall capability of the Internet Computer ecosystem. By providing a clear guideline for data processing and transfer, this proposal aims to streamline development efforts, reduce complexity, and encourage the creation of more sophisticated and interconnected dApps on the Internet Computer network.

### Motivation

The motivation behind this ICRC proposal stems from the growing need for a standardized, efficient mechanism to handle and process data across different canisters on the Internet Computer platform. As the ecosystem expands, the interaction between various canisters becomes increasingly complex and pivotal for the development of advanced decentralized applications (dApps). This complexity highlights the necessity for a unified protocol that addresses several key aspects:

1. **Interoperability**: With a multitude of canisters operating on the Internet Computer, ensuring seamless data exchange and processing capabilities is crucial. This standard aims to foster interoperability, allowing canisters to effectively communicate and collaborate regardless of their underlying implementation details.

2. **Scalability**: As dApps grow in complexity and size, the ability to process large volumes of data efficiently becomes vital. This proposal introduces a scalable approach to handle extensive data workloads, enabling canisters to manage large datasets effectively and maintain high performance.

3. **Security and Reliability**: Ensuring the integrity and security of data during processing and transfer is a key concern. The proposed standard incorporates mechanisms for secure data handling, including provisions for data chunking and validation, thereby enhancing the overall reliability of inter-canister interactions.

4. **Developer Experience**: By providing a clear and comprehensive standard, this ICRC aims to simplify the development process for dApp creators. A unified framework reduces the learning curve and development overhead, allowing developers to focus on building innovative solutions rather than dealing with compatibility and data management intricacies.

5. **Good Shape**: The standard aims to be "shaped like the Internet Computer." While the IC provides amazing features there are technical limitations. The standard specifically addresses the limitation of size(about 2MB) between canisters and the cycle limit inherent to each round of computing. This standard, and the supporting components that will be built around the standard can significancy reduce a developers need to consider these features and will hopefully provide components that 'just work'.

# Specification

The keywords "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in [RFC 2119](https://www.ietf.org/rfc/rfc2119.txt).

### Intended Use

The ICRC standard for processing workloads between canisters on the DFINITY Internet Computer is designed with versatility and scalability in mind, catering to a variety of use cases within the Internet Computer ecosystem. Here are the primary intended uses, along with examples for each:

#### 1. Intercanister Communication
- **Target**: Facilitates communication between a client canister (requestor) and a processor canister (executor) where the latter performs a designated workload.
- **Example**: Consider a decentralized finance (DeFi) application where a user's wallet canister (client) requests a trading canister (processor) to execute complex trade algorithms. The wallet canister sends the trade parameters to the trading canister, which processes the request and returns the trade execution results.

#### 2. Mono-Canister Processing
- **Target**: Simplifies coding within single-canister applications that require executing their processing logic in a stepwise, multi-round manner.
- **Example**: An AI model training canister could use this standard to handle large datasets in chunks. The canister initially sets up the training parameters (like model architecture) and then processes data in batches, adjusting weights iteratively in a stepwise fashion until the training is complete.

#### 3. Ingress from Outside the Internet Computer
- **Target**: Supports applications that require multi-step processing or handling large datasets, with data originating from outside the IC.
- **Example**: A meme dApp might want to make custom image filters available to users without having to expose the code base. The a social dapp may upload these items into an Internet Computer canister, wait for them to be processed in multiple steps, and download the resulting images into the web app.


### Logic Flow of Data Processing in ProcessActor

The `ProcessActor` in the proposed ICRC standard outlines a comprehensive flow for processing data, especially for workloads exceeding 2MB. The process involves several steps, each handling specific parts of data processing and retrieval. Below is a detailed explanation of the logic flow, accompanied by a UML sequence diagram illustrating the interactions between the components.

#### 1. **Initiate Processing with `process` Method**
- **Description**: Start the data processing task. You can include data directly if it is less than 2MB, or opt to send it later using `pushChunk` for larger datasets.
- **Outcome**: 
  - If data is included and under 2MB
    - Processing can begins immediately for one step workflows
      - If the response is under 2MB it may be returned immediately.
      - If the response is over 2MB the canister will be able to retrieve it using getChunk
    - For multi-step workflows, step instructions are returned
  - If data is not included or exceeds 2MB, the method returns a `#IntakeNeeded` response, indicating that you need to push data using `pushChunk`.
    - Once all the data is sent
      - Processing can begins immediately for one step workflows
        - If the response is under 2MB it may be returned immediately.
        - If the response is over 2MB the canister will be able to retrieve it using getChunk
      - For multi-step workflows, step instructions are returned

#### 2. **Optional: Push Data Using `pushChunk`**
- **When**: If the initial `process` call returns `#IntakeNeeded`.
- **Description**: Send data chunks to the canister for processing.
- **Outcome**: 
  - `#SingleStep`: Indicates manual processing steps are required or waiting for `#OnLoad` processing to complete.
  - `#OuttakeNeeded`: Your data is ready for processing.
  - `#DataIncluded`: The data fits in one chunk and can be directly returned.

#### 3. **Optional: Manually Process with `singleStep`**
- **When**: If you receive a `#SingleStep` response and the processing type is `#Manual`.
- **Description**: Manually trigger processing steps.
- **Outcome**: Continues processing until completion or until no further manual steps are needed.

#### 4. **Optional: Check Processing Status**
- **When**: If using `#OnLoad` processing type.
- **Description**: Regularly call `getProcessingStatus` to check the progress of the processing task.
- **Outcome**: Returns the current status of processing, indicating whether it's complete or still in progress.

#### 5. **Optional: Retrieve Large Data Sets**
- **When**: If you get an `#OuttakeNeeded` response.
- **Description**: Use `getChunk` to retrieve all data chunks.
- **Outcome**: Allows you to reassemble the data in your calling canister.

## Important Types



### ProcessRequest

```
  public type ProcessRequest = {
    event: ?Text;  //User may provide an event namespace
    caller: ?Principal;
    expiresAt : ?Int;
    dataConfig: ?DataConfig;
    executionConfig: ?ExecutionConfig;
    responseConfig: ?ResponseConfig;
  };
```

#### Structure of `ProcessRequest`

The `ProcessRequest` type, used as an input for the `process` function in the `ProcessActor`, is a critical component in the data processing workflow. It encapsulates various parameters and configurations necessary for initiating and handling the processing of data. Below is an exhaustive documentation of the `ProcessRequest` type:

##### 1. `event`
- **Type**: `?Text`
- **Description**: An optional parameter that may represent an event namespace or identifier associated with the processing request. It can be used for logging, tracking, or categorizing processing tasks. For Canister that handle multiple events, the canister can use this event namespace to route the data to the proper processing pipeline.

##### 2. `caller`
- **Type**: `?Principal`
- **Description**: An optional parameter indicating the identity of the caller (user or canister) initiating the processing request. This is crucial for authorization and access control purposes.  If provided, this principal will be able to push data(Unless overridden in the DataConfig), call single steps in manual processing mode, and retrieve responses(unless overridden in the response config).

##### 3. `expiresAt`
- **Type**: `?Int`
- **Description**: An optional timestamp indicating the expiration time of the request. If the processing does not commence before this time, the request may be considered invalid or expired.(Default 2 minutes after submission).

#### 4. `dataConfig`
- **Type**: `?DataConfig`
```
public type DataConfig  = {
      #DataIncluded : {
          data: [CandyTypes.AddressedChunk]; //data if small enough to fit in the message
      };
      #Local : Nat; // A local identifier on the server used to identify data
      #Push : ?{
        permission: ?Principal;
        totalChunks: Nat; //must tell the canister how many chunks to expect
      };
      #Internal;
  };
  ```
- **Description**: Specifies how the data for processing should be handled. It's a variant that can take multiple forms:
   - `#DataIncluded`: Directly includes the data if it's small enough to fit within the message.  Data is included as an CandyType Addressed Chunk array that can be loaded into an CandyType Workspace.(See ICRC16)
   - `#Local`: Refers to data that may already reside within the canister. Provide an id that the canister will understand so that it can retrieve and stage the data for processing.
   - `#Push`: Indicates that data will be pushed to the canister using the `pushChunk` method.
   - `#Internal`: Used for internal handling of the data, not typically set in initial requests.

#### 5. `executionConfig`
- **Type**: `?ExecutionConfig`

```
public type ExecutionConfig = {
    #OnLoad;
    #Manual;
  };
```
- **Description**: Determines how the processing task should be executed. It's a variant with options like:
   - `#OnLoad`: Indicates that processing should begin as soon as the data is loaded. The canister will use a timer and attempt to finalize processing
   - `#Manual`: Requires manual intervention to proceed with processing steps, typically through the `singleStep` method.

#### 6. `responseConfig`
- **Type**: `?ResponseConfig`
```
public type ResponseConfig = {
      #Include;
      #Pull : ?{
        permission: ?Principal;
        totalChunks: Nat;
      };
      #Local : Nat;
  };
  ```
- **Description**: Specifies how the response to the processing request should be handled. It's a variant with options like:
   - `#Include`: Directly includes the response data in the processing response. Note: if the data exceeds the maxChunkSize of a particular server, the canister may return an #OuttakeNeeded response
   - `#Pull`: Indicates that the response data should be pulled or retrieved separately. Optionally set a permission for which principal can pull the result.(Useful if you want the results to go to a storage canister).
   - `#Local`: Refers to a local reference for the response data, usually within the same canister. 

#### 7. `createdAt`
- **Type**: `Int`
- **Description**: A timestamp used for deduplication of requests.

### Usage
The `ProcessRequest` is used to encapsulate all necessary information for processing a task. When a client or another canister makes a processing request, it constructs a `ProcessRequest` instance with the appropriate fields and sends it to the `ProcessActor`. The `ProcessActor` then interprets this request and proceeds with the processing according to the specified configurations.

### Example
Here's a hypothetical example of a `ProcessRequest`:
```motoko
{
    event = ?"image-processing",
    caller = ?Principal.fromText("aaaaa-aa"),
    expiresAt = ?1625097600000,
    dataConfig = ?#Push(?{ permission = null; totalChunks = 10; }),
    executionConfig = ?#OnLoad,
    responseConfig = ?#Include
}
```
This request might represent an image processing task, where the data is sent in chunks, processed upon arrival, and the response is expected to be included directly in the processing result.

### ProcessResponse

```
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
  ```

The `ProcessResponse` type in the `ProcessActor` is essential for conveying the status and results of a data processing request. It's a variant type, meaning it can take different forms based on the processing stage or outcome. Below is an exhaustive documentation of each variant in the `ProcessResponse` type:

#### Structure of `ProcessResponse`

`ProcessResponse` is an optional type (denoted by `?`), which means it can also be `null`. This is provided for future upgradeability and a ProcessResponse MUST not be null.

##### 1. `#DataIncluded`
- **Type**: `?{ payload: [CandyTypes.AddressedChunk] }`
- **Description**: This variant is used when the processed data is small enough to be included directly in the response.
- **Fields**:
  - `payload`: An array of `AddressedChunk`. Each `AddressedChunk` contains a part of the processed data.

##### 2. `#Local`
- **Type**: `Nat`
- **Description**: Indicates that the processed data is stored locally within the canister and can be accessed using the provided identifier.
- **Fields**:
  - This variant is a single natural number (`Nat`), serving as an identifier or reference to the locally stored data.

##### 3. `#IntakeNeeded`
- **Type**: `?{ pipeInstanceID: PipeInstanceID; currentChunks: Nat; totalChunks: Nat; chunkMap: [Bool] }`
- **Description**: Signals that the processing request requires additional data to be sent in chunks.
- **Fields**:
  - `pipeInstanceID`: A unique identifier for the processing pipeline instance.
  - `currentChunks`: The number of data chunks already received.
  - `totalChunks`: The total number of chunks expected for the processing.
  - `chunkMap`: An array of booleans indicating which chunks have been received (`true`) and which are still pending (`false`).

##### 4. `#OuttakeNeeded`
- **Type**: `?{ pipeInstanceID: PipeInstanceID }`
- **Description**: Indicates that the processed data is ready but too large to include directly in the response. It should be retrieved separately.
- **Fields**:
  - `pipeInstanceID`: The unique identifier for the processing pipeline instance to retrieve the data from.

##### 5. `#StepProcess`
- **Type**: `?{ pipeInstanceID: PipeInstanceID; status: ProcessType }`
- **Description**: Used in scenarios where processing occurs in steps or stages, especially for manual or complex processing tasks.
- **Fields**:
  - `pipeInstanceID`: The unique identifier for the processing instance.
  - `status`: An enumeration (`ProcessType`) indicating the current processing stage or type.

##### 6. `#Assigned`
- **Type**: `{ pipeInstanceID: PipeInstanceID; canister: Principal }`
- **Description**: Indicates that the processing task has been assigned to another server or canister for processing.
- **Fields**:
  - `pipeInstanceID`: The unique identifier for the processing instance.
  - `canister`: The `Principal` identifier of the canister where the process has been assigned.

#### Usage
The `ProcessResponse` is used by the `ProcessActor` to communicate the status, results, and further action required for a processing request. Depending on the processing task's nature, size, and complexity, the appropriate variant of `ProcessResponse` is returned to the caller.

#### Example
Here's an example of a `ProcessResponse` indicating that more data chunks are needed:
```motoko
#IntakeNeeded(?{
    pipeInstanceID = 12345;
    currentChunks = 3;
    totalChunks = 10;
    chunkMap = [true, true, true, false, false, false, false, false, false, false];
})
```
This response suggests that the process, identified by `pipeInstanceID = 12345`, has received 3 out of 10 expected data chunks, with the first three chunks already received (as indicated by the `chunkMap`).


## Methods
Each method in the `ProcessActor` plays a specific role:

### 1. `process` Method
- **Purpose**: Initiates, and optionally complete, the processing of a workload.
- **Input**: `ProcessRequest` - Contains details about the processing task, including the data configuration, execution configuration, and the response configuration.
- **Output**: `Result<Result<ProcessResponse, ProcessError>>` - Asynchronously returns a `ProcessResponse` indicating the outcome of the process or a `ProcessError` in case of failure.
- **Process Flow**:
  - Validates the request.
  - Determines how data will be loaded based on the `dataConfig`.
  - Executes the processing steps.
  - Returns a response indicating the status of processing or an error.

### 2. `pushChunk` Method
- **Purpose**: Allows for pushing a chunk of data to the processing canister.
- **Input**: `ChunkPush` - Contains the chunk to be processed and associated metadata.

```
public type ChunkPush = {
    pipeInstanceID: PipeInstanceID;
    chunk: ChunkDetail;
  };
```

- **Output**: `Result<Result<ProcessResponse, ProcessError>>` - Asynchronously returns a response related to the processing of the pushed chunk or an error.
- **Process Flow**:
  - Validates the push request.
  - Adds the chunk to the processing queue or storage.
  - Returns a status update on the processing of the chunk.

### 3. `getPushStatus` Method
- **Purpose**: Queries the status of a push operation. This query method is useful for external dapps that need to monitor the progress of chunk uploading form outside the Internet Computer.
- **Input**: `PushStatusRequest` - Identifies the specific push operation whose status is being queried.
```
  public type PushStatusRequest = {
    pipeInstanceID: PipeInstanceID;
  };
```
- **Output**: `Result<Result<ProcessResponse, ProcessError>>` - Asynchronously returns the current status of the push operation or an error.
- **Process Flow**:
  - Checks the status of the specified push request.
  - Returns the current status, such as pending, complete, or error.

### 4. `getProcessingStatus` Method
- **Purpose**: Queries the overall status of the processing task.
- **Input**: `ProcessingStatusRequest` - Specifies the processing task whose status is being queried.

```
public type ProcessingStatusRequest = {
    pipeInstanceID: PipeInstanceID;
  };
```

- **Output**: `Result<Result<ProcessResponse, ProcessError>>` - Asynchronously returns the current status of the processing task or an error.
- **Process Flow**:
  - Evaluates the current progress of the processing task.
  - Returns information such as completed steps, pending steps, or any errors.

### 5. `singleStep` Method
- **Purpose**: Executes a single step in the processing sequence.
- **Input**: `StepRequest` - Specifies the details of the step to be executed.
```
public type StepRequest = {
    pipeInstanceID: PipeInstanceID;
    step: ?Nat;
  };
```

For sequential flows, the step will typically be null.  For flows with Parallel execution, the canister can initiate multiple calls, each operating on a different step of the process. This is useful for known operation sizes that can be calculated deterministic.

- **Output**: `Result<Result<ProcessResponse, ProcessError>>` - Asynchronously returns the outcome of the executed step or an error.
- **Process Flow**:
  - Validates and executes the specified step in the processing task.
  - Returns the result of the step, which could include the need for further steps, completion, or an error.

### 6. `getChunk` Method
- **Purpose**: Retrieves a specific chunk of data.
- **Input**: `ChunkGet` - Specifies the chunk ID and other related information to identify the chunk needed.

``` 
  public type ChunkGet = {
    chunkID: Nat;
    chunkSize: Nat;
    pipeInstanceID: PipeInstanceID;
  };
  ```

  The chunkSize should be consistent across each call to get the full dataset.

- **Output**: `Result<Result<ChunkResponse, ProcessError>>` - Asynchronously returns the requested data chunk or an error.

```
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
  
```

Note that the client is responsible for determining when and if they have received all the response chunks.

- **Process Flow**:
  - Validates the chunk request.
  - Fetches the specified chunk from the processing data.
  - Returns the chunk data or an error if the chunk cannot be found or accessed.

---

## Security Considerations

The proposed ICRC standard for processing workloads between canisters on the Internet Computer places significant emphasis on security, particularly in how processes are accessed and managed. It's important to note that while the standard provides a robust framework for data processing and transfer, it adopts an agnostic stance towards security at the process level. This approach allows for flexibility and adaptability in various implementation contexts. Below are the key security considerations:

#### 1. Agnosticism at the Process Level
- **Flexibility in Implementation**: The standard does not enforce specific security protocols or access control mechanisms at the process level. Instead, it leaves the decision on securing access to functions to the discretion of the individual implementation. This allows developers to tailor security measures according to the unique requirements and context of their application.  Implementations MAY restrict who can initiate a process, push chunks, call steps, and retrieve steps at the implementation level using access lists or other methods.
- **Responsibility of Implementation**: While offering flexibility, this agnosticism places the responsibility on developers to implement appropriate security measures. Implementers are encouraged to carefully consider and integrate security protocols that best fit their application's nature and risk profile.

#### 2. Configurable Access Control
- **Explicit Security Configurations**: The standard allows specific sections of the process to have explicit security configurations. For example, developers MAY define who is authorized to push data, invoke the step function, or retrieve processed data.
- **Use of Null Values for Open Access**: In cases where open access is desired, the protocol permits the use of null values in security configurations. This means that if no explicit security constraints are set (i.e., values are left as null), the process or function becomes accessible without restrictions unless the implementation has implemented other methods.
- **Balancing Flexibility and Security**: The use of explicit configurations versus null values offers a balance between flexibility and security. It enables developers to lock down sensitive parts of the process flow while potentially leaving others more open, depending on the use case.
- **Recommendations for Implementers**: It is recommended that implementers carefully evaluate which parts of the process require stringent access controls and which can be more open. Factors such as the sensitivity of data being processed, the potential impact of unauthorized access, and the overall security posture of the application should guide these decisions.


## Todo:

The following features should be considered during ICRC consideration:

- Formalization of ICRC16 inclusion
- One shot notification and a consumer spec for listening. Or do we use ICRCE events?
- Function to retrieve current processe requests and statuses
- Define transaction log shape (ICRC3)
- Review the need for a Process lock
- Deduplication
- Manually cleaning up

