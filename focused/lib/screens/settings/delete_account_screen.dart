
import 'package:flutter/material.dart';
import '../../services/account_lifecycle_service.dart';

class DeleteAccountScreen extends StatefulWidget{
 const DeleteAccountScreen({super.key});
 @override State<DeleteAccountScreen> createState()=>_DeleteAccountScreenState();
}
class _DeleteAccountScreenState extends State<DeleteAccountScreen>{
 final email=TextEditingController();
 bool busy=false;
 Future<void> remove() async{
  final user=await importFirebaseUser();
 }
 Future<dynamic> importFirebaseUser() async {
  final service=AccountLifecycleService();
  // handled by Firebase current user inside service
  if(email.text.trim().isEmpty)return;
  setState(()=>busy=true);
  try{await service.deleteAccount(); if(mounted)Navigator.pop(context);}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext c)=>Scaffold(
 appBar:AppBar(title:const Text('Delete account')),
 body:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
 const Text('This permanently deletes your Focused account and cloud data.'),
 TextField(controller:email,decoration:const InputDecoration(labelText:'Enter your email')),
 FilledButton(onPressed:busy?null:remove,child:const Text('Delete permanently'))
 ])));
}
