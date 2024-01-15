
    //error list
    //
    // Intake push errors
    // 8 - cannot find intake cache for provided id
    // 9 - Cannot add to a 'done' intake cache
    // 10 - Do not send an error chunk type to the intake process
    // 11 - Unloaded Intake Cache. Should Not Be Here.
    // 12 - Request cache is missing.
    // 16 - Do not send an error chunk
    // 29 - Unauthorized

    // GetChunk errors
    // 13 -- cannot find response cache

    //pushChunk
    // 14 -- parallel - pipe already pushed
    // 15 -- done loading

    //pushChunk Status
    //17 -- Pipe is not in intake state
    //30 -- Not a push type
    //31 -- Index out of bounds

    //single step
    //19 -- error with step
    //20 -- map missing
    //21 -- processing not ready
    //22 -- done processing
    //27 -- cannot find cache;
    //28 -- cannot find request cache;
    //32 -- Execution config missing

    //inputs
    //23 - Improper data config
    //24 - Cannot Find Request in Cache
    //25 - Improper execution config
    //26 - Improperly configured response config
    //33 - expired

