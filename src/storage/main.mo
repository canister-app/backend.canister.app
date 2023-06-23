import TrieMap "mo:base/TrieMap";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Bool "mo:base/Bool";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import P "mo:base/Prelude";
import Http "./http";
import Types "./types";
import Debug "mo:base/Debug";

actor class CanicActor() = this{
    type FileId = Types.FileId;
    type FileInit = Types.FileInit;
    type UserId = Types.UserId;
    type FileInfo = Types.FileInfo;
    type ChunkData = Types.ChunkData;
    type ChunkId = Types.ChunkId;
    var state = Types.empty();

    private var admins : Buffer.Buffer<Principal> = Buffer.Buffer(0);

    private func _isAdmin(p : Principal) : Bool {
        for (a in admins.vals()) {
            if (a == p) { return true; };
        };
        false;
    };

    public shared(msg) func createFile(i : FileInit) : async ?FileId {
        do?{
            let fileId = await createFile_(i, msg.caller);
            fileId!
        }
    };
     private func createFile_(fileData : FileInit, userId: UserId) : async ?FileId {
        let now = Time.now();
        let fileId = fileData.name;//"/" # Principal.toText(userId) # "/" # fileData.path;
        Debug.print("fileId::::"#fileId);
        //!!!! Overwrite existed file
        state.files.put(fileId, {
                    fileId = fileId;
                    userId = userId;
                    name = fileData.name;
                    createdAt = now;
                    chunkCount = fileData.chunkCount;
                    fileSize = fileData.fileSize;
                    mimeType = fileData.mimeType;
                });
        ?fileId
    };
    func chunkId(fileId : FileId, chunkNum : Nat) : ChunkId {
        fileId # (Nat.toText(chunkNum));
    };
    // Get all files
    public query(msg) func getFiles() : async ?[(FileId, FileInfo)] {
        do?{
            assert(_isAdmin(msg.caller));
            Iter.toArray(state.files.entries());
        }
    };
    // Put File Chunk
    public shared(msg) func putFileChunk
        (fileId : FileId, chunkNum : Nat, chunkData : ChunkData) : async ()
        {
        state.chunks.put(chunkId(fileId, chunkNum), chunkData);
    };

    // Get File Chunk
    public query(msg) func getFileChunk(fileId : FileId, chunkNum : Nat) : async ?ChunkData {
        _getFileChunk(fileId, chunkNum);
    };

     private func _getFileChunk(fileId : FileId, chunkNum : Nat) : ?ChunkData {
        let chunkData : ?ChunkData = state.chunks.get(chunkId(fileId,chunkNum));
        state.chunks.get(chunkId(fileId, chunkNum));
    };

    private func getFileChunks({fileId : FileId;chunkCount : Nat}) : [ChunkData] {
        let b = Buffer.Buffer<ChunkData>(0);
        var chunkNum : Nat = 1;
        while(chunkNum <= chunkCount){
            let chunkData = unwrap<ChunkData>(state.chunks.get(chunkId(fileId, chunkNum)));
            b.add(chunkData);
            chunkNum += 1;
        };
        b.toArray();
    };
    private func unwrap<T>(x : ?T) : T =
        switch x {
            case null { P.unreachable() };
            case (?x_) { x_ };
        };

    public shared query({caller}) func http_request({url: Text;} : Http.HttpRequest) : async Http.HttpResponse {
        let path = Iter.toArray<Text>(Text.tokens(url, #text("/")));
        switch(state.files.get(path[0])){
            case(null) {
                let _path = "not-found.png";
                switch(state.files.get(_path)){
                    case (?fileInfo){
                        return {
                            status_code =200;
                            headers = [("Content-Type", fileInfo.mimeType)];
                            body = Blob.toArray(unwrap<ChunkData>(_getFileChunk(_path, 1)));
                            streaming_strategy = createStrategy(fileInfo.fileId,1,fileInfo.chunkCount);
                        }
                    };
                    case _{
                      return {
                        body = Blob.toArray(Text.encodeUtf8("<html><title>404 - Not Found</title><body style='color: #444; margin:0;font: normal 14px/20px Arial, Helvetica, sans-serif; height:100%; background-color: #fff;' cz-shortcut-listen='true'><div style='height:auto; min-height:100%; '> <div style='text-align: center; width:800px; margin-left: -400px; position:absolute; top: 30%; left:50%;'> <h1 style='margin:0; font-size:150px; line-height:150px; font-weight:bold;'>404</h1><h2 style='margin-top:20px;font-size: 30px;'>Not Found</h2><p>The resource requested could not be found on this canister.</p></div></div></body></html>"));
                        headers = [];
                        status_code = 404;
                        streaming_strategy = null;
                    }
                    }
                }
                
            };
            case (?fileInfo){
                return {
                        status_code =200;
                        headers = [("Content-Type", fileInfo.mimeType)];
                        body = Blob.toArray(unwrap<ChunkData>(_getFileChunk(path[0], 1)));
                        streaming_strategy = createStrategy(fileInfo.fileId,1,fileInfo.chunkCount);
                    }
                
            };
        }

    };

    private func createStrategy(key: Text, index: Nat, chunkCount : Nat) : ?Http.StreamingStrategy {
        if(chunkCount == 1){
            return null;
        }else{
            let streamingToken: ?Http.StreamingCallbackToken = createToken(key, index, chunkCount);
            switch (streamingToken) {
                case (null) { null };
                case (?streamingToken) {
                    let self: Principal = Principal.fromActor(this);
                    let canisterId: Text = Principal.toText(self);

                    let canister = actor (canisterId) : actor { http_request_streaming_callback : shared () -> async () };
                    Debug.print("createStrategy"# debug_show(streamingToken));
                    return ?#Callback({
                        token = streamingToken;
                        callback = canister.http_request_streaming_callback;
                    });
                };
            };
        }
    };

    private func createToken(key: Text, chunkIndex: Nat, chunkCount:Nat) : ?Http.StreamingCallbackToken {
        Debug.print("createToken"# debug_show(key,chunkIndex));
        if (chunkIndex + 1 > chunkCount) {
            return null;
        };

        let streamingToken: ?Http.StreamingCallbackToken = ?{
            key = key;
            index = chunkIndex + 1;
            content_encoding = "gzip";
            sha256 = null;
        };

        return streamingToken;
    };
    public shared(msg) func removeFile(fileId: Text): async (){
        assert(_isAdmin(msg.caller));
        switch(state.files.get(fileId)){
            case (?file){
                state.files.delete(fileId);
                state.chunks.delete(chunkId(fileId, file.chunkCount));
                 Debug.print("Deleted file: "# fileId);
            };
            case _ ();

        }
        
    };

    private stable var chunkArray : [(ChunkId, ChunkData)] = [];
    private stable var fileArray : [(FileId, FileInfo)] = [];
    private stable var adminsArray : [Principal] = [Principal.fromText("lekqg-fvb6g-4kubt-oqgzu-rd5r7-muoce-kppfz-aaem3-abfaj-cxq7a-dqe")];

    system func preupgrade() {
        chunkArray := Iter.toArray(state.chunks.entries());
        fileArray := Iter.toArray(state.files.entries());
        adminsArray := admins.toArray();
    };

    system func postupgrade(){
        for ((chunkId, chunkData) in chunkArray.vals()) {
            state.chunks.put(chunkId, chunkData);
        };
        for ((fileId, fileInfo) in fileArray.vals()) {
            state.files.put(fileId, fileInfo);
        };
        for (admin in adminsArray.vals()) {
            admins.add(admin);
        };
    };

    public func getAdmins() : async [Principal] {
        admins.toArray();
    };

}