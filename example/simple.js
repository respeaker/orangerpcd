global.WebSocket = require("ws"); 
global.$ = require("jquery-deferred"); 
require("./rpc2"); 

RPC.$connect("ws://localhost:1234").done(function(){
	RPC.$list("*").done(function(result){
		console.log("List: "+result); 
	}); 
	RPC.$call("/session", "access", {}).done(function(result){
		console.log("session.access: "+result); 
	}); 
	RPC.$call("/uci", "configs", {}).done(function(result){
		console.log("configs: "+result); 
	}); 
	RPC.$call("/uci", "revert", {}).done(function(result){
		console.log("revert: "+result); 
	}); 
	RPC.$call("/juci/ethernet", "adapters", {foo:"bar"}).done(function(result){
		console.log("Netstat: "+result); 
	}); 
	RPC.$call("/simple","print_hello", { message: "Hello World!" }).done(function(result){
		console.log("Call completed: "+result); 
	}); 
	RPC.$call("/simple","print_hello", { message: "Hello World!" }).done(function(result){
		console.log("Call completed! "+result); 
	}); 
}); 
