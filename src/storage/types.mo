import TrieMap "mo:base/TrieMap";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Bool "mo:base/Bool";
import Principal "mo:base/Principal";

module {
    public type UserId = Principal;
    public type UserName = Text;
    public type FileId = Text; // chosen by createFile
    public type ChunkId = Text; // FileId # (toText(ChunkNum))
    public type ChunkData = Blob; // encoded as ??
    public type Map<X, Y> = TrieMap.TrieMap<X, Y>;

    public type FileInit = {
        name: Text;
        path: Text;
        chunkCount: Nat;
        fileSize: Nat;
        mimeType: Text;
    };

    public type FileInfo = {
        fileId : FileId; //UUID 
        userId: UserId;
        createdAt : Int;
        name: Text;
        chunkCount: Nat;
        fileSize: Nat;
        mimeType: Text;
    };

    public type State = {
        files : Map<FileId, FileInfo>;
        /// all chunks.
        chunks : Map<ChunkId, ChunkData>;
        /// all files.
    };

    public func empty () : State {

        let st : State = {
            chunks = TrieMap.TrieMap<ChunkId, ChunkData>(Text.equal, Text.hash);
            files = TrieMap.TrieMap<FileId, FileInfo>(Text.equal, Text.hash);
        };
        st
    };
}