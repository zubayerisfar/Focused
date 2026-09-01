
import 'package:flutter/material.dart';
import '../../services/account_lifecycle_service.dart';

class DeactivateAccountScreen extends StatefulWidget {
 const DeactivateAccountScreen({super.key});
 @override State<DeactivateAccountScreen> createState()=>_DeactivateAccountScreenState();
}
class _DeactivateAccountScreenState extends State<DeactivateAccountScreen>{
 final reasons=<String>{};
 final feedback=TextEditingController();
 final options=[
  'I need a break',
  'I do not use Focused anymore',
  'Missing features',
  'Technical problems',
  'Privacy concerns',
  'Using another app',
  'Other',
 ];
 Future<void> submit() async{
  if(reasons.isEmpty)return;
  await AccountLifecycleService().deactivate(reasons: reasons.toList(), feedback: feedback.text);
  if(mounted) Navigator.of(context).pop();
 }
 @override Widget build(BuildContext c)=>Scaffold(
 appBar: AppBar(title: const Text('Deactivate account')),
 body: ListView(padding: const EdgeInsets.all(16),children:[
 const Text('Your account will be paused for 24 hours. Tell us why:'),
 ...options.map((e)=>CheckboxListTile(value:reasons.contains(e),title:Text(e),onChanged:(v)=>setState(()=>v==true?reasons.add(e):reasons.remove(e)))),
 TextField(controller:feedback,decoration:const InputDecoration(labelText:'Additional feedback')),
 const SizedBox(height:20),
 FilledButton(onPressed:submit,child:const Text('Deactivate')),
 ]));
}
