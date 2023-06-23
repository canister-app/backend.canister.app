import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Time "mo:base/Time";
import Array "mo:base/Array";
import AccountId "mo:accountid/AccountId";
import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Types "./types";

module Utils {

    // Convert principal id to subaccount id.
    public func principalToSubAccount(id: Principal) : [Nat8] {
        let p = Blob.toArray(Principal.toBlob(id));
        Array.tabulate(32, func(i : Nat) : Nat8 {
            if (i >= p.size() + 1) 0
            else if (i == 0) (Nat8.fromNat(p.size()))
            else (p[i - 1])
        })
    };
    // Helper function to be used with 'find' calls.
    public func eqId(id: Principal) : { id: Principal } -> Bool {
        func (x: { id: Principal }) { x.id == id }
    };

    //Create subaccount array
    public func getAccountArrByUserId(cid: Principal, userId: Principal): [Nat8]{
        let subaccount = Utils.principalToSubAccount(userId);
        AccountId.fromPrincipal(cid, ?subaccount)
    };

    public func getAccountByUserId(cid: Principal, userId: Principal): Text{
        let subaccount = Utils.principalToSubAccount(userId);
        let account = toHex(AccountId.fromPrincipal(cid, ?subaccount));
        account;
    };

  public func toHex(arr: [Nat8]): Text {
    let hexChars = ["0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"];
    Text.join("", Iter.map<Nat8, Text>(Iter.fromArray(arr), func (x: Nat8) : Text {
      let a = Nat8.toNat(x / 16);
      let b = Nat8.toNat(x % 16);
      hexChars[a] # hexChars[b]
    }))
  };
  // Return a new 'User' struct, filled with default values.
  public func newUser(id: Principal, cid: Principal) : Types.User {
    let _account = Utils.getAccountByUserId(cid, id);
    { 
        id = id;
        var username        = "";
        account         = _account; //Set account id by user principal, for topup cycle
        var verified        = false;
        var bio             = "";
        var cycle_balance   = 0;//Available to Topup
        var title           = "";//Member, Canister Team, Dfinity Foundation...ect
        var links           = ?[];//Social Link, email..
        var updated_at      = Time.now();
        created_at      = Time.now();
    };
  };
}
