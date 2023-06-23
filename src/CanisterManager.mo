
import IC "./ic";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Result "mo:base/Result";
import Error "mo:base/Error";
import Principal "mo:base/Principal";
import Types "types";

module {
    let ic: IC.Self = actor "aaaaa-aa";
    //Get canister status
    public func canister_status(canister_id: IC.canister_id): async Types.CanisterStatus{
        await ic.canister_status({canister_id = canister_id})
    };
    //Request new canister
    public func create_canister(self: IC.user_id, creator: IC.user_id, init_cycle: Nat): async Result.Result<IC.canister_id, Text>{
        let settings = {
            freezing_threshold = null;
            controllers = ?[self, creator];
            memory_allocation = null;
            compute_allocation = null;
        };
        Cycles.add(init_cycle);//Topup init cycles to new canister
        try{
            let result = await ic.create_canister({ settings = ?settings; });
            return #ok(result.canister_id);
        }catch(e){
            let message = Error.message(e);
            return #err(message);
        }
    };
    
    // Install
    public func install_code(canister_id : IC.canister_id, arg: [Nat8], wasm: Blob) : async Result.Result<Bool, Text>{
        //Cycles.add(1_000_000_000_000);
        try{
            await ic.install_code ({
                        arg = arg;
                        wasm_module = Blob.toArray(wasm);
                        mode = #install;
                        canister_id = canister_id;
                        });
            return #ok(true);
        }catch(e){
            let message = Error.message(e);
            return #err(message);
        }
    };
    // Reinstall
    public func reinstall_code(canister_id : IC.canister_id, arg: [Nat8], wasm: Blob) : async Result.Result<Bool, Text>{
        // Cycles.add(1_000_000_000_000);
        try{
            await ic.install_code ({
                arg = arg;//[]; 
                wasm_module = Blob.toArray(wasm);
                mode = #reinstall;
                canister_id = canister_id;
            });
            return #ok(true);
        }catch(e){
            let message = Error.message(e);
            return #err(message);
        }
    };
    
    //Start canister
    public func start_canister(canister_id: IC.canister_id) : async(){
        await ic.start_canister({ canister_id = canister_id });
    };

    //Stop canister
    public func stop_canister(canister_id: IC.canister_id) : async(){
        await ic.stop_canister({ canister_id = canister_id });
    };
    //Delete canister!!!
    public func delete_canister(canister_id: IC.canister_id) : async (){
        await ic.stop_canister({ canister_id = canister_id });
        await ic.delete_canister({ canister_id = canister_id });
    };
    //Topup cycles
    public func topup(amount: Nat, canister_id: IC.canister_id): async (){
        let amountTopup = amount*1_000_000_000_000;
        if(Cycles.balance() > amountTopup){
            Cycles.add amountTopup;
            await ic.deposit_cycles({canister_id})
        }
    };
}