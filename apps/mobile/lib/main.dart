import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show LicenseRegistry, LicenseEntryWithLineBreaks;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'live_service.dart';

const emerald = Color(0xff165d48);
const ink = Color(0xff192b25);
const paper = Color(0xfffcfbf7);
const sage = Color(0xffedf5ef);
const amber = Color(0xfffff1d8);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Qur’an text — Tanzil'], await rootBundle.loadString('assets/licenses/TANZIL-NOTICE.txt'));
    yield LicenseEntryWithLineBreaks(['Quran JSON — Risan Bagja'], await rootBundle.loadString('assets/licenses/CORPUS-LICENSE.txt'));
    yield LicenseEntryWithLineBreaks(['Amiri font'], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  try {
    final store = AppStore(await SharedPreferences.getInstance());
    final chapters = await Chapter.load();
    runApp(JanabApp(store: store, chapters: chapters));
  } catch (_) {
    runApp(const MaterialApp(home: Scaffold(body: Center(child: Padding(
      padding: EdgeInsets.all(24), child: Text('Unable to open the Qur’an text. Please reinstall the app.'))))));
  }
}

class JanabApp extends StatefulWidget {
  final AppStore store;
  final List<Chapter> chapters;
  const JanabApp({super.key, required this.store, required this.chapters});
  @override State<JanabApp> createState() => _JanabAppState();
}

class _JanabAppState extends State<JanabApp> {
  late String language = widget.store.language;
  String token = ''; // Personal development token, retained only in memory.
  void refresh() => setState(() { language = widget.store.language; });
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'Qur’an Janab', debugShowCheckedModeBanner: false,
    locale: Locale(language), supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(seedColor: emerald, primary: emerald, surface: Colors.white),
      textTheme: ThemeData.light().textTheme.apply(bodyColor: ink, displayColor: ink),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: ink, centerTitle: false, scrolledUnderElevation: 0),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        minimumSize: const Size(48, 54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: paper,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
      dividerColor: const Color(0xffe7ebe5)),
    home: HomeScreen(store: widget.store, chapters: widget.chapters, language: language,
      onChange: refresh, getToken: () => token, setToken: (value) => token = value),
  );
}

String tr(String language, String en, String ar) => language == 'ar' ? ar : en;

class HomeScreen extends StatefulWidget {
  final AppStore store;
  final List<Chapter> chapters;
  final String language;
  final VoidCallback onChange;
  final String Function() getToken;
  final void Function(String) setToken;
  const HomeScreen({super.key, required this.store, required this.chapters,
    required this.language, required this.onChange, required this.getToken, required this.setToken});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  String query = '';
  String t(String en, String ar) => tr(widget.language, en, ar);
  Future<void> openChapter(Chapter chapter, {int start = 1, int? end}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SetupScreen(
      chapter: chapter, start: start, end: end ?? chapter.verses.length,
      store: widget.store, token: widget.getToken(), language: widget.language)));
    if (mounted) { setState(() {}); }
  }
  @override Widget build(BuildContext context) {
    final history = widget.store.history;
    return Scaffold(
      appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('Qur’an Janab', 'قرآن جناب'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 22)),
        Text(t('A little closer, every day', 'خطوة أقرب، كل يوم'), style: const TextStyle(fontSize: 12, color: Color(0xff66766b))),
      ]), actions: [IconButton(tooltip: t('Settings', 'الإعدادات'), icon: const Icon(Icons.tune_rounded), onPressed: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen(
          store: widget.store, initialToken: widget.getToken(), onToken: widget.setToken, onChange: widget.onChange)));
        if (mounted) { setState(() {}); }
      })]),
      body: SafeArea(child: tab == 2 ? _history(history) : CustomScrollView(slivers: [
        if (tab == 0) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(24, 20, 24, 8), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Make room for\nyour recitation.', 'وقتٌ لتلاوتك.'), style: const TextStyle(fontSize: 34, height: 1.18, fontWeight: FontWeight.w500, letterSpacing: -1)),
            const SizedBox(height: 22),
            Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: emerald, borderRadius: BorderRadius.circular(24)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Icon(Icons.auto_stories_rounded, color: Colors.white), const SizedBox(width:10),
                  Text(t('YOUR NEXT PRACTICE', 'تدريبك القادم'), style: const TextStyle(color: Color(0xffd3e9d9), fontSize: 11, letterSpacing: 1.2))]),
                const SizedBox(height: 18),
                Text(history.isEmpty ? t('Begin with Al-Fātiḥah', 'ابدأ بالفاتحة') : t('Continue your journey', 'تابع رحلتك'),
                  style: const TextStyle(color: Colors.white, fontSize: 24)),
                const SizedBox(height: 8), Text(t('Read, listen, repeat. At your pace.', 'اقرأ واستمع وكرّر، على مهل.'), style: const TextStyle(color: Color(0xffd3e9d9))),
                const SizedBox(height:20),
                FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: emerald),
                  onPressed: () => history.isEmpty ? openChapter(widget.chapters.first) : openChapter(widget.chapters[history.first.surah - 1], start: history.first.start, end: history.first.end),
                  icon: const Icon(Icons.arrow_forward_rounded), label: Text(t('Start practice', 'ابدأ التدريب'))),
              ])),
            const SizedBox(height: 20),
            _Notice(icon: Icons.headphones_rounded, text: t('Explore demo mode without a microphone. Live practice requires your configured backend.', 'جرّب العرض دون ميكروفون. التدريب المباشر يحتاج إلى إعداد الخادم.')),
            const SizedBox(height: 24), Text(t('Choose your surah', 'اختر السورة'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
          ]))),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(24,16,24,12), child: TextField(
          onChanged: (s) => setState(() => query = s.toLowerCase()),
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: t('Search by name or number', 'ابحث بالاسم أو الرقم'))))),
        SliverList(delegate: SliverChildListDelegate(widget.chapters.where((c) => '${c.name} ${c.transliteration.toLowerCase()} ${c.id}'.contains(query)).map((c) =>
          ListTile(contentPadding: const EdgeInsets.symmetric(horizontal:24, vertical:6),
            leading: Container(width:44, height:44, alignment:Alignment.center, decoration: BoxDecoration(color:sage,borderRadius:BorderRadius.circular(14)), child:Text('${c.id}',style:const TextStyle(color:emerald))),
            title:Text(widget.language == 'ar' ? c.name : c.transliteration, style:const TextStyle(fontWeight:FontWeight.w500)),
            subtitle:Text('${c.verses.length} ${t('ayat', 'آيات')}',style:const TextStyle(fontSize:12)),
            trailing: widget.language == 'ar' ? const Icon(Icons.chevron_left_rounded) : Text(c.name,textDirection:TextDirection.rtl,style:const TextStyle(fontSize:23)),
            onTap:()=>openChapter(c))).toList())),
        const SliverToBoxAdapter(child:SizedBox(height:24)),
      ])),
      bottomNavigationBar: NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),backgroundColor:Colors.white,indicatorColor:sage,
        destinations:[NavigationDestination(icon:const Icon(Icons.home_outlined),selectedIcon:const Icon(Icons.home_rounded),label:t('Home','الرئيسية')),
          NavigationDestination(icon:const Icon(Icons.menu_book_rounded),label:t('Qur’an','القرآن')),
          NavigationDestination(icon:const Icon(Icons.history_rounded),label:t('Practice','التدريب'))]),
    );
  }
  Widget _history(List<PracticeRecord> history) {
    if (history.isEmpty) { return Center(child:Padding(padding:const EdgeInsets.all(32),child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Icon(Icons.spa_outlined,size:52,color:emerald),const SizedBox(height:20),Text(t('Your practice begins here','هنا يبدأ تدريبك'),style:const TextStyle(fontSize:24)),
      const SizedBox(height:12),Text(t('Finish a session to save a passage for next time.','أكمل جلسة لحفظ موضع تدريبك القادم.'),textAlign:TextAlign.center)]))); }
    return ListView(padding:const EdgeInsets.all(24),children:[Text(t('Your practice','تدريبك'),style:const TextStyle(fontSize:28)),const SizedBox(height:16),
      ...history.map((r)=>Card(elevation:0,color:paper,margin:const EdgeInsets.only(bottom:12),child:ListTile(
        contentPadding:const EdgeInsets.all(16),title:Text(widget.language=='ar'?widget.chapters[r.surah-1].name:widget.chapters[r.surah-1].transliteration),
        subtitle:Text('${r.start}–${r.end} · ${r.seconds~/60}:${(r.seconds%60).toString().padLeft(2,'0')}\n${r.demo?t('Demo • not assessed','عرض • دون تقييم'):t('Experimental • transcript only','تجريبي • مطابقة النص فقط')}'),
        trailing:const Icon(Icons.replay_rounded,color:emerald),onTap:()=>openChapter(widget.chapters[r.surah-1],start:r.start,end:r.end)))),
    ]);
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Notice({required this.icon,required this.text});
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:sage,borderRadius:BorderRadius.circular(16)),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,size:20,color:emerald),const SizedBox(width:12),Expanded(child:Text(text,style:const TextStyle(fontSize:13,height:1.5,color:ink)))]));
}

class SetupScreen extends StatefulWidget {
  final Chapter chapter;
  final int start,end;
  final AppStore store;
  final String token,language;
  const SetupScreen({super.key,required this.chapter,required this.start,required this.end,required this.store,required this.token,required this.language});
  @override State<SetupScreen> createState()=>_SetupScreenState();
}
class _SetupScreenState extends State<SetupScreen> {
  late int start=widget.start,end=widget.end;
  late bool hifz=widget.store.hifz;
  bool live=false,ack=false;
  String t(String en,String ar)=>tr(widget.language,en,ar);
  @override Widget build(BuildContext context){
    final passage=Passage(widget.chapter,start,end);
    final configured=widget.store.server.isNotEmpty&&widget.token.length>=24;
    final enabled=!live||(ack&&configured&&passage.liveEligible);
    return Scaffold(appBar:AppBar(title:Text(t('Prepare your practice','إعداد التدريب'))),body:ListView(padding:const EdgeInsets.all(24),children:[
      Center(child:Text(widget.chapter.name,textDirection:TextDirection.rtl,style:const TextStyle(fontSize:40,height:1.8))),
      Center(child:Text(widget.chapter.transliteration,style:const TextStyle(color:emerald))),const SizedBox(height:28),
      Row(children:[Expanded(child:DropdownButtonFormField<int>(value:start,isExpanded:true,decoration:InputDecoration(labelText:t('From ayah','من الآية')),
        items:List.generate(widget.chapter.verses.length,(i)=>DropdownMenuItem(value:i+1,child:Text('${i+1}'))),
        onChanged:(v)=>setState((){start=v!;if(end<start)end=start;}))),const SizedBox(width:16),
        Expanded(child:DropdownButtonFormField<int>(value:end,isExpanded:true,decoration:InputDecoration(labelText:t('To ayah','إلى الآية')),
          items:List.generate(widget.chapter.verses.length-start+1,(i)=>DropdownMenuItem(value:start+i,child:Text('${start+i}'))),onChanged:(v)=>setState(()=>end=v!)))]),
      const SizedBox(height:24),Text(t('How would you like to practise?','كيف ترغب في التدريب؟'),style:const TextStyle(fontSize:19)),const SizedBox(height:12),
      SegmentedButton<bool>(segments:[ButtonSegment(value:false,label:Text(t('Read','قراءة')),icon:const Icon(Icons.menu_book_rounded)),ButtonSegment(value:true,label:Text(t('Hifz','حفظ')),icon:const Icon(Icons.visibility_off_outlined))],selected:{hifz},onSelectionChanged:(v)=>setState(()=>hifz=v.first)),
      const SizedBox(height:24),Text(t('Session type','نوع الجلسة'),style:const TextStyle(fontSize:19)),const SizedBox(height:12),
      SegmentedButton<bool>(segments:[ButtonSegment(value:false,label:Text(t('Demo','عرض'))),ButtonSegment(value:true,label:Text(t('Live beta','مباشر تجريبي')))],selected:{live},onSelectionChanged:(v)=>setState(()=>live=v.first)),
      const SizedBox(height:16),_Notice(icon:live?Icons.science_outlined:Icons.touch_app_outlined,text:live?t('Experimental word-sequence checks only. No tajwīd grading. Audio is sent to OpenAI; this app does not save recordings.','مطابقة تجريبية لتسلسل الكلمات، دون تقييم التجويد. يُرسل الصوت إلى OpenAI ولا يحفظ التطبيق التسجيلات.'):t('A guided interface demonstration. No microphone, no AI connection, and no assessment.','عرض لتجربة الواجهة، دون ميكروفون أو اتصال بالذكاء الاصطناعي أو تقييم.')),
      if(live&&!configured)Padding(padding:const EdgeInsets.only(top:16),child:Text(t('Add your backend URL and app access token in Settings first.','أضف عنوان الخادم ورمز الوصول في الإعدادات أولًا.'),style:const TextStyle(color:Color(0xff865d20)))),
      if(live&&!passage.liveEligible)Padding(padding:const EdgeInsets.only(top:16),child:Text(t('Choose up to 10 ayat and a shorter passage for live practice. The full text remains available in demo reading.','اختر حتى ١٠ آيات ومقطعًا أقصر للتدريب المباشر. النص الكامل متاح في العرض.'))),
      if(live)CheckboxListTile(contentPadding:EdgeInsets.zero,value:ack,onChanged:(v)=>setState(()=>ack=v!),title:Text(t('I understand that checks can be wrong.','أفهم أن المطابقة قد تخطئ.'))),
      const SizedBox(height:24),Text(t('Feedback: English','لغة الشرح: العربية'),style:const TextStyle(color:emerald)),const SizedBox(height:16),
      FilledButton.icon(onPressed:enabled?()async{
        await widget.store.preferences.setBool('hifz',hifz);
        if(!context.mounted)return;
        await Navigator.of(context).push(MaterialPageRoute(builder:(_)=>PracticeScreen(passage:passage,store:widget.store,language:widget.language,hifz:hifz,live:live,token:widget.token)));
      }:null,icon:Icon(live?Icons.mic_none_rounded:Icons.play_arrow_rounded),label:Text(live?t('Start live practice','ابدأ التدريب المباشر'):t('Explore demo','جرّب العرض'))),
      const SizedBox(height:12),Text(t('Hafs text • immediate review requests','نص حفص • طلبات مراجعة فورية'),textAlign:TextAlign.center,style:const TextStyle(fontSize:12,color:Color(0xff68776a))),
    ]));
  }
}

enum PracticePhase{ready,connecting,listening,review,retry,paused,ended,error}

class PracticeScreen extends StatefulWidget{
  final Passage passage;
  final AppStore store;
  final String language,token;
  final bool hifz,live;
  const PracticeScreen({super.key,required this.passage,required this.store,required this.language,required this.hifz,required this.live,required this.token});
  @override State<PracticeScreen> createState()=>_PracticeScreenState();
}
class _PracticeScreenState extends State<PracticeScreen> with WidgetsBindingObserver{
  PracticePhase phase=PracticePhase.ready;
  LiveService? service;
  int cursor=0,reviews=0,epoch=0;
  bool reveal=false,busy=false,saved=false,completed=false,cancelAfterConnect=false;
  String caption='',error='';
  final stopwatch=Stopwatch();
  Timer? ticker;
  bool finalization=true;
  String t(String en,String ar)=>tr(widget.language,en,ar);
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);
    ticker=Timer.periodic(const Duration(seconds:1),(_){if(mounted&&stopwatch.isRunning)setState((){});});
    if(!widget.live){phase=PracticePhase.listening;stopwatch.start();}
  }
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);ticker?.cancel();if(service!=null)unawaited(service!.stop());super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state!=AppLifecycleState.resumed&&state!=AppLifecycleState.inactive&&phase!=PracticePhase.ended){
      if(phase==PracticePhase.connecting){cancelAfterConnect=true;service?.cancelCapture();}
      else{unawaited(pause());}
    }
  }
  void event(Map<String,dynamic> e){
    if(!mounted||phase==PracticePhase.ended||phase==PracticePhase.paused||phase==PracticePhase.error)return;
    final nextEpoch=e['epoch'] as int?;
    if(nextEpoch!=null&&nextEpoch<epoch)return;
    setState((){
      if(nextEpoch!=null)epoch=nextEpoch;
      switch(e['type']){
        case 'position':cursor=(e['cursor'] as int).clamp(0,widget.passage.words.length).toInt();break;
        case 'review':case 'unclear':
          reviews++;phase=PracticePhase.review;cursor=(e['cursor'] as int?)??cursor;caption='';
          service?.setTutorAudible(true);HapticFeedback.mediumImpact();break;
        case 'retry_started':phase=PracticePhase.retry;cursor=e['cursor'] as int;caption='';break;
        case 'retry_aligned':phase=PracticePhase.listening;break;
        case 'passage_aligned':completed=true;unawaited(finish());break;
        case 'caption':caption=(caption+(e['delta'] as String)).characters.take(600).toString();break;
        case 'error':error=t('Live connection failed. Checking has stopped. You can end this session and try again.','تعذّر الاتصال. توقفت المطابقة. يمكنك إنهاء الجلسة والمحاولة من جديد.');phase=PracticePhase.error;stopwatch.stop();unawaited(service?.stop()??Future.value(false));break;
        case 'closed':finalization=e['finalization_confirmed']==true;if(phase!=PracticePhase.ended){unawaited(pause());}break;
      }
    });
  }
  Future<void> start()async{
    if(busy)return;
    setState((){busy=true;phase=PracticePhase.connecting;error='';epoch=0;cursor=0;cancelAfterConnect=false;});
    service=LiveService(server:widget.store.server,token:widget.token,onEvent:event);
    try{
      await service!.start(widget.passage,widget.language);
      if(cancelAfterConnect){await service!.stop();if(mounted)setState(()=>phase=PracticePhase.paused);}
      else if(mounted&&phase==PracticePhase.connecting){setState(()=>phase=PracticePhase.listening);stopwatch.start();}
    }catch(_){if(mounted)setState((){phase=PracticePhase.error;error=t('Could not start live audio. Check your microphone permission, backend address, token, and API access.','تعذّر بدء الصوت. تحقّق من إذن الميكروفون وعنوان الخادم ورمز الوصول وإتاحة الخدمة.');});}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> pause()async{
    if(busy||phase==PracticePhase.paused||phase==PracticePhase.ended)return;
    setState((){phase=PracticePhase.paused;busy=true;});stopwatch.stop();
    if(service!=null){finalization=await service!.stop();service=null;}
    if(mounted)setState(()=>busy=false);
  }
  Future<void> finish()async{
    if(saved||busy)return;
    setState((){busy=true;phase=PracticePhase.ended;});stopwatch.stop();
    if(service!=null){finalization=await service!.stop();service=null;}
    if(!saved){saved=true;await widget.store.add(PracticeRecord(surah:widget.passage.chapter.id,start:widget.passage.start,end:widget.passage.end,
      seconds:stopwatch.elapsed.inSeconds,reviews:reviews,demo:!widget.live,completed:completed,date:DateTime.now()));}
    if(mounted)setState(()=>busy=false);
  }
  void demoAdvance(){
    setState((){cursor=(cursor+1).clamp(0,widget.passage.words.length).toInt();phase=PracticePhase.listening;});
    if(cursor==widget.passage.words.length){completed=true;unawaited(finish());}
  }
  Future<bool> leave()async{
    if(busy)return false;
    if(phase!=PracticePhase.ended)await finish();
    return true;
  }
  String get status=>switch(phase){
    PracticePhase.ready=>t('Ready when you are','جاهز عندما تكون مستعدًا'),
    PracticePhase.connecting=>t('Connecting…','جارٍ الاتصال…'),
    PracticePhase.listening=>widget.live?t('Listening • experimental checks','أستمع • مطابقة تجريبية'):t('Demo • microphone off','عرض • الميكروفون مغلق'),
    PracticePhase.review=>t('Let’s review this phrase','لنراجع هذه العبارة'),
    PracticePhase.retry=>t('Listening for your retry','أستمع إلى محاولتك'),
    PracticePhase.paused=>t('Paused • microphone off','متوقف • الميكروفون مغلق'),
    PracticePhase.ended=>t('Session finished','انتهت الجلسة'),
    PracticePhase.error=>t('Checking stopped','توقفت المطابقة'),
  };
  @override Widget build(BuildContext context){
    final total=widget.passage.words.length;
    return PopScope(canPop:phase==PracticePhase.ended&&!busy,onPopInvokedWithResult:(didPop,result)async{
      if(!didPop&&await leave()&&context.mounted)Navigator.of(context).pop();
    },child:Scaffold(backgroundColor:paper,appBar:AppBar(title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(widget.language=='ar'?widget.passage.chapter.name:widget.passage.chapter.transliteration),
      Text('${t('Ayat','الآيات')} ${widget.passage.start}–${widget.passage.end}',style:const TextStyle(fontSize:12,color:emerald))]),
      actions:[if(widget.hifz)IconButton(tooltip:t('Show or hide text','إظهار النص أو إخفاؤه'),onPressed:()=>setState(()=>reveal=!reveal),icon:Icon(reveal?Icons.visibility_off_outlined:Icons.visibility_outlined))]),
      body:SafeArea(child:Column(children:[
        Padding(padding:const EdgeInsets.symmetric(horizontal:24,vertical:12),child:Row(children:[
          Icon(widget.live?Icons.science_outlined:Icons.touch_app_outlined,size:16,color:emerald),const SizedBox(width:8),
          Expanded(child:Text(widget.live?t('Live beta · no tajwīd grading','مباشر تجريبي · دون تقييم التجويد'):t('Interface demonstration · no assessment','عرض الواجهة · دون تقييم'),style:const TextStyle(fontSize:12,color:emerald))),
          Text('${stopwatch.elapsed.inMinutes}:${(stopwatch.elapsed.inSeconds%60).toString().padLeft(2,'0')}',style:const TextStyle(fontSize:12)),
        ])),
        Expanded(child:phase==PracticePhase.ended?_summary():ListView(padding:const EdgeInsets.fromLTRB(24,12,24,20),children:[
          if(widget.hifz&&!reveal&&phase!=PracticePhase.review)Padding(padding:const EdgeInsets.symmetric(vertical:50),child:Column(children:[
            const Icon(Icons.spa_outlined,size:48,color:emerald),const SizedBox(height:20),Text(t('Recite from your heart','تَلُ من حفظك'),style:const TextStyle(fontSize:26)),const SizedBox(height:12),
            Text(t('The passage is hidden. Tap the eye for a hint.','النص مخفي. اضغط على رمز العين للتلميح.'),textAlign:TextAlign.center)]))
          else ..._verseWidgets(),
        ])),
        if(phase!=PracticePhase.ended)Container(decoration:const BoxDecoration(color:Colors.white,borderRadius:BorderRadius.vertical(top:Radius.circular(28))),padding:const EdgeInsets.fromLTRB(24,18,24,16),child:Column(mainAxisSize:MainAxisSize.min,children:[
          Semantics(liveRegion:true,child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[Container(width:7,height:7,decoration:BoxDecoration(color:phase==PracticePhase.review?const Color(0xff936222):emerald,shape:BoxShape.circle)),const SizedBox(width:8),Flexible(child:Text(status,textAlign:TextAlign.center,style:const TextStyle(fontSize:13,color:emerald)))])),
          const SizedBox(height:12),
          if(phase==PracticePhase.review)Container(width:double.infinity,padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:amber,borderRadius:BorderRadius.circular(16)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(t('Pause, please','توقّف قليلًا، من فضلك'),style:const TextStyle(fontWeight:FontWeight.w600)),const SizedBox(height:6),
            Text(widget.live?t('I may have heard a different word. Repeat the highlighted phrase. This is a review request, not a confirmed mistake.','ربما سمعت كلمة مختلفة. أَعِد العبارة المحدّدة. هذا طلب مراجعة وليس حكمًا بوجود خطأ.'):t('Example correction. Tap Try again to explore the retry flow.','تصحيح توضيحي. اضغط على المحاولة لاستكشاف الخطوة التالية.'),style:const TextStyle(height:1.5,fontSize:14)),
            if(caption.isNotEmpty)Padding(padding:const EdgeInsets.only(top:8),child:Text(caption,style:const TextStyle(fontSize:13))),
          ])),
          if(phase==PracticePhase.error)Padding(padding:const EdgeInsets.only(bottom:12),child:Text(error,style:const TextStyle(color:Color(0xff8b391e)),textAlign:TextAlign.center)),
          if(phase==PracticePhase.paused&&widget.live)Padding(padding:const EdgeInsets.only(bottom:12),child:Text(t('Live pause closes the connection. Restart begins at the selected passage’s first word.','الإيقاف يغلق الاتصال. تبدأ إعادة التشغيل من أول كلمة في المقطع.'),style:const TextStyle(fontSize:12),textAlign:TextAlign.center)),
          const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton(onPressed:busy?null:_primary,child:busy?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)):Text(_primaryLabel))),
          const SizedBox(height:6),Row(children:[
            if(!widget.live&&(phase==PracticePhase.listening||phase==PracticePhase.retry))Expanded(child:TextButton(onPressed:(){setState((){phase=PracticePhase.review;reviews++;});HapticFeedback.mediumImpact();},child:Text(t('Preview correction','معاينة التصحيح')))),
            Expanded(child:TextButton(onPressed:busy?null:finish,child:Text(t('End session','إنهاء الجلسة')))),
          ]),
          if(widget.live&&total>0)Text(t('Position is estimated; pronunciation is not assessed.','الموضع تقديري، ولا يُقيَّم النطق.'),textAlign:TextAlign.center,style:const TextStyle(fontSize:11,color:Color(0xff657166))),
        ])),
      ])),
    ));
  }
  List<Widget> _verseWidgets(){
    int offset=0;
    return widget.passage.verses.map((verse){
      final begin=offset;final words=verse.text.split(RegExp(r'\s+'));offset+=words.length;
      final active=cursor>=begin&&cursor<offset;
      if(widget.hifz&&!reveal&&!active)return const SizedBox.shrink();
      return Padding(padding:const EdgeInsets.only(bottom:24),child:Semantics(label:'${widget.passage.chapter.name}, ${verse.id}',child:Column(children:[
        Text.rich(TextSpan(children:[for(int i=0;i<words.length;i++)TextSpan(text:'${words[i]} ',style:TextStyle(
          backgroundColor:cursor==begin+i?(phase==PracticePhase.review?amber:sage):Colors.transparent)),
          TextSpan(text:' ﴿${verse.id}﴾',style:const TextStyle(color:Color(0xff806b46),fontSize:20))]),
          textDirection:TextDirection.rtl,textAlign:TextAlign.center,style:TextStyle(fontSize:widget.store.textSize,height:2.15,fontFamily:'Amiri')),
        if(active)Padding(padding:const EdgeInsets.only(top:8),child:Text(t('Current passage','المقطع الحالي'),style:const TextStyle(fontSize:11,color:emerald))),
      ])));
    }).toList();
  }
  String get _primaryLabel{
    if(phase==PracticePhase.ready||phase==PracticePhase.error)return t('Connect microphone','توصيل الميكروفون');
    if(phase==PracticePhase.paused)return widget.live?t('Restart live session','إعادة بدء الجلسة'):t('Resume demo','متابعة العرض');
    if(phase==PracticePhase.review)return t('Try again','حاول مرة أخرى');
    return widget.live?t('Pause practice','إيقاف مؤقت'):t('Next word','الكلمة التالية');
  }
  void _primary(){
    if(phase==PracticePhase.ready||phase==PracticePhase.error){unawaited(start());return;}
    if(phase==PracticePhase.paused){if(widget.live){unawaited(start());}else{setState(()=>phase=PracticePhase.listening);stopwatch.start();}return;}
    if(phase==PracticePhase.review){setState(()=>phase=PracticePhase.retry);if(widget.live){service?.retry();}else{cursor=cursor>0?cursor-1:0;}return;}
    if(widget.live){unawaited(pause());}else{demoAdvance();}
  }
  Widget _summary()=>ListView(padding:const EdgeInsets.all(28),children:[
    const Icon(Icons.check_circle_outline_rounded,size:56,color:emerald),const SizedBox(height:20),Text(t('A moment well spent.','وقتٌ طيبٌ مع القرآن.'),textAlign:TextAlign.center,style:const TextStyle(fontSize:28)),const SizedBox(height:24),
    _Notice(icon:Icons.info_outline_rounded,text:widget.live?t('Session saved. Sequence matching does not certify pronunciation or tajwīd.','حُفظت الجلسة. مطابقة التسلسل لا تثبت صحة النطق أو التجويد.'):t('Demo complete. No recitation was recorded or assessed.','اكتمل العرض. لم تُسجّل أو تُقيّم أي تلاوة.')),
    const SizedBox(height:20),ListTile(title:Text(t('Review requests','طلبات المراجعة')),trailing:Text('$reviews')),
    if(!finalization)Text(t('Service finalization was not confirmed. Check backend logs and API usage before restarting.','لم يُؤكَّد إغلاق الخدمة. راجع الخادم والاستخدام قبل إعادة التشغيل.')),
    const SizedBox(height:20),FilledButton(onPressed:busy?null:()=>Navigator.of(context).pop(),child:Text(t('Back to practice','العودة للتدريب'))),
  ]);
}

class SettingsScreen extends StatefulWidget{
  final AppStore store;
  final String initialToken;
  final void Function(String) onToken;
  final VoidCallback onChange;
  const SettingsScreen({super.key,required this.store,required this.initialToken,required this.onToken,required this.onChange});
  @override State<SettingsScreen> createState()=>_SettingsScreenState();
}
class _SettingsScreenState extends State<SettingsScreen>{
  late String language=widget.store.language;
  late double size=widget.store.textSize;
  late final server=TextEditingController(text:widget.store.server);
  late final token=TextEditingController(text:widget.initialToken);
  String t(String en,String ar)=>tr(language,en,ar);
  @override void dispose(){server.dispose();token.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(t('Settings','الإعدادات'))),body:ListView(padding:const EdgeInsets.all(24),children:[
    Text(t('Teaching language','لغة الشرح'),style:const TextStyle(fontSize:22)),const SizedBox(height:12),
    SegmentedButton<String>(segments:const[ButtonSegment(value:'en',label:Text('English')),ButtonSegment(value:'ar',label:Text('العربية'))],selected:{language},onSelectionChanged:(v)=>setState(()=>language=v.first)),
    const SizedBox(height:12),Text(t('Reciting Arabic never changes your explanation language.','تلاوة القرآن لا تغيّر لغة الشرح المختارة.')),
    const SizedBox(height:28),Text(t('Qur’an text size','حجم خط القرآن'),style:const TextStyle(fontSize:22)),
    Slider(value:size,min:26,max:46,divisions:10,label:'${size.round()}',onChanged:(v)=>setState(()=>size=v)),
    Text('بِسْمِ اللَّهِ',textDirection:TextDirection.rtl,textAlign:TextAlign.center,style:TextStyle(fontSize:size,height:2)),
    const SizedBox(height:24),Text(t('Live connection','الاتصال المباشر'),style:const TextStyle(fontSize:22)),const SizedBox(height:12),
    TextField(controller:server,keyboardType:TextInputType.url,autocorrect:false,decoration:InputDecoration(labelText:t('Backend URL','عنوان الخادم'),hintText:'https://your-api.example.com')),
    const SizedBox(height:12),TextField(controller:token,obscureText:true,autocorrect:false,enableSuggestions:false,decoration:InputDecoration(labelText:t('App access token','رمز وصول التطبيق'))),
    const SizedBox(height:12),Text(t('Use your backend access token, not an OpenAI API key. The token stays in memory and must be entered again after restarting the app.','استخدم رمز وصول الخادم، وليس مفتاح OpenAI. يبقى الرمز في الذاكرة فقط ويلزم إدخاله بعد إعادة تشغيل التطبيق.'),style:const TextStyle(fontSize:12,height:1.5)),
    const SizedBox(height:28),FilledButton(onPressed:()async{
      await widget.store.preferences.setString('language',language);await widget.store.preferences.setDouble('textSize',size);await widget.store.preferences.setString('server',server.text.trim());
      widget.onToken(token.text.trim());widget.onChange();if(context.mounted)Navigator.of(context).pop();
    },child:Text(t('Save settings','حفظ الإعدادات'))),
    const SizedBox(height:20),TextButton(onPressed:()async{
      final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(t('Delete practice history?','حذف سجل التدريب؟')),
        content:Text(t('This removes saved sessions from this device.','سيُحذف سجل الجلسات من هذا الجهاز.')),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:Text(t('Cancel','إلغاء'))),TextButton(onPressed:()=>Navigator.pop(c,true),child:Text(t('Delete','حذف')))]));
      if(yes==true){await widget.store.clearHistory();if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('History deleted','حُذف السجل'))));}
    },child:Text(t('Delete local practice history','حذف سجل التدريب المحلي'))),
    const Divider(height:36),Text(t('Text attribution','مصدر النص'),style:const TextStyle(fontWeight:FontWeight.w600)),const SizedBox(height:8),
    const Text('Quran JSON — Risan Bagja\nhttps://github.com/risan/quran-json\nCC BY-SA 4.0 • Original text retained unchanged.\nQur’an text: Tanzil Project • https://tanzil.net\nCopyright © 2007–2021 Tanzil Project • CC BY 3.0\nhttps://tanzil.net/docs/Text_License',style:TextStyle(fontSize:12,height:1.6)),
    const SizedBox(height:16),Text(t('Version 0.1.0 • Experimental practice companion\nNo audio recordings are stored by this app. Provider retention is governed by your API account configuration.','الإصدار 0.1.0 • مساعد تدريب تجريبي\nلا يحفظ التطبيق تسجيلات صوتية. تخضع سياسة احتفاظ المزوّد بإعدادات حساب الخدمة.'),style:const TextStyle(fontSize:12,height:1.6)),
    const SizedBox(height:12),const Text('Amiri font • SIL Open Font License 1.1',style:TextStyle(fontSize:12)),
    TextButton(onPressed:()=>showLicensePage(context:context,applicationName:'Qur’an Janab',applicationVersion:'0.1.0'),child:Text(t('View licenses','عرض التراخيص'))),
  ]));
}
