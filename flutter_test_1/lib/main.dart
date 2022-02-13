import 'package:flutter/cupertino.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;


late final SharedPreferences userPreferences;
late final Database addressDatabase, ordersDatabase;
const uuid = Uuid();
const Map<String, double> discountCodes = {"SCONTO10": 0.1, "SCONTO20": 0.2, "SCONTO30": 0.3};
Directory? imagesDirectory;
List<Wine> wineList = [];
List<String> wineTypes = [];
late final double screenWidth;
late final double screenHeight;
late final AppSizes sizes;

class AppSizes {
  late double screenWidth;
  late double screenHeight;
  static const Size _wineName = Size(0.05, 0.05);
  static const Size _producerName = Size(0.03, 0.03);
  static const Size _description = Size(0.02, 0.02);
  static const Size _icons = Size(0.025, 0.025);
  static const Size _bottleNumber = Size(0.05, 0.05);
  static const Size _price = Size(0.03, 0.03);
  static const Size _wineImage = Size(0.2, 0.2);
  static const Size _addRemoveButtons = Size(0.01, 0.01);
  static const Size _shoppingCartImage = Size(0.15, 0.15);
  static const Size _shoppingCartPrice = Size(0.03, 0.03);
  static const Size _shoppingCartName = Size(0.03, 0.03);
  static const Size _thanksMessage = Size(0.03, 0.03);
  static const Size _textSmall = Size(0.02, 0.02);
  static const Size _textLarge = Size(0.03, 0.03);


  Size get wineName{ return toActualSize(_wineName); }
  Size get producerName{ return toActualSize(_producerName); }
  Size get description{ return toActualSize(_description); }
  Size get icons{ return toActualSize(_icons); }
  Size get bottleNumber{ return toActualSize(_bottleNumber); }
  Size get price{ return toActualSize(_price); }
  Size get wineImage{ return toActualSize(_wineImage); }
  Size get addRemoveButtons{ return toActualSize(_addRemoveButtons); }
  Size get shoppingCartImage{ return toActualSize(_shoppingCartImage); }
  Size get shoppingCartPrice{ return toActualSize(_shoppingCartPrice); }
  Size get shoppingCartName{ return toActualSize(_shoppingCartName); }
  Size get thanksMessage{ return toActualSize(_thanksMessage); }
  Size get textSmall{ return toActualSize(_textSmall); }
  Size get textLarge{ return toActualSize(_textLarge); }

  Size toActualSize(Size percentageValue){
    return Size(percentageValue.width * screenWidth, percentageValue.height * screenHeight);
  }

  AppSizes({required this.screenWidth, required this.screenHeight});
}

class Order {
  late String id;
  late Client client;
  Map<Wine, int> wines = {};
  double discount = 0;

  Order({Client? client}) : super()
  {
    client = client ?? Client();
    id = uuid.v1();
  }

  int amountOf(Wine wine) {
    if (wines[wine] == null) {
      return 0;
    } else {
      return wines[wine]!;
    }
  }

  int get numberOfWines {
    return wines.length;
  }

  double get totalPriceCents{
    double total = 0;

    for (Wine wine in wines.keys){
      total += wine.priceInCents * amountOf(wine);
    }
    return total;
  }

  void addBottles(Wine wine, {int? amount}){
    debugPrint("[Order.addBottles()] Aggiungendo vino: ${wine.name}, ${(amount ?? wine.minimumQuantity).toString()} bottiglie");
    wines.update(
      wine,
      (value) => value + (amount ?? wine.minimumQuantity),
      ifAbsent: () => (amount ?? wine.minimumQuantity)
    );
  }

  void removeBottles(Wine wine, {int? amount}){
    wines.update(
        wine,
        (value) => max(0, value - (amount ?? wine.minimumQuantity)),
        ifAbsent:()=>0,
    );
    wines.removeWhere((key, value) => (value == 0));
  }

  void updateWineList(Wine wine, int deltaAmount) {
    wines.update(wine, (value) => max(0, value + deltaAmount),
        ifAbsent: () => max(0, deltaAmount));
    wines.removeWhere((key, value) => (value == 0));
  }

  void removeWine(Wine wine){
    wines.remove(wine);
  }

  @override
  String toString(){
    String newString;

    newString = '\n===================================\n';
    newString = newString + "Nom: " + client.fullName + '\n';
    newString = newString + "Addresse: " + client.address + '\n';
    newString = newString + "Email: " + client.email + '\n';
    newString = newString + "Telephone: " + client.telephoneNumber + '\n';
    newString = newString + 'Total: ' + (totalPriceCents * 0.01).toStringAsFixed(2);
    if (discount > 0){
      newString = newString + 'Rabais: ' + discount.toString();
      newString = newString + 'Total: ' + (totalPriceCents * 0.01 * discount).toStringAsFixed(2);
    }
    newString = newString + '\n===================================';
    for (Wine wine in wines.keys){
      newString = newString + '\n' + wine.toString() + '\nAmount:' + wines[wine].toString();
      newString = newString + '\n--------------------------------------';
    }
    return newString;
  }
}

class Client {
  String name;
  String surname;
  String city;
  String street;
  String streetNumber;
  String telephoneNumber;
  String email;
  late String id;

  String get fullName{
    return name + ' ' + surname;
  }

  String get address{
    return city + ', ' + street + ' ' + streetNumber;
  }

  Client({this.name="", this.surname="", this.city="", this.street="", this.streetNumber="", this.telephoneNumber="", this.email=""}){
    id = uuid.v1();
  }

  @override
  String toString(){
    return "Name: $name\n Surname: $surname\n Address: $city, $street $streetNumber\n Phone: $telephoneNumber\n E-mail: $email";
  }

  Map toMapForDatabase(){
    return {
      'nome': name,
      'cognome': surname,
      'citta': city,
      'strada': street,
      'numero_civico': streetNumber,
      'telefono': telephoneNumber,
      'email': email,
      'id': id
    };
  }

  static const List<String> headerNamesCSV = [
    'id',
    'nome',
    'cognome',
    'citta',
    'strada',
    'numero_civico',
    'telefono',
    'email',
  ];

  List<String> formattedForCSV(){
    return [id, name, surname, city, street, streetNumber, telephoneNumber, email];
  }
}

bool stringToBool(String string, {bool defaultValue=false}){
  if  ((string.toLowerCase() == 'true')||
      (string.toLowerCase() == 'si')||
      (string.toLowerCase() == 'yes')){
    return true;
  }else if ((string.toLowerCase() == 'false')||
      (string.toLowerCase() == 'no')){
    return false;
  }
  else{
    return defaultValue;
  }
}

class Wine {
  static const List<String> headerNamesCSV = [
    'id',
    'nome',
    'dettagli',
    'url_immagine',
    'alcool',
    'temperatura_servizio',
    'ordine_minimo',
    'prezzo_in_cents',
    'anno',
    'contiene_solfiti',
    'volume_cc',
    'produttore',
    'tipo',
    'denominazione',
  ];

  String id;
  String name;
  String details;
  String imageFile;
  double? alcohol;
  double temperature;
  int minimumQuantity;
  int priceInCents;
  int? year;
  bool containsSulfites;
  int volume_cc;
  String producer;
  String type;
  String? denominazione;

  static Wine fromList(List<String> fieldNames, List<dynamic> values){
    Map<String, dynamic> rawDataMap = {};

    for(String columnName in Wine.headerNamesCSV){
      if (!fieldNames.contains(columnName)){
        throw("[wine.fromList] Attenzione! Cercando di caricare un vino da una lista di valori, ma la lista fornita non contiene il campo $columnName!}");
      }
    }

    for(int index=0; index < fieldNames.length; index++){
      rawDataMap[fieldNames[index]] = values[index];
    }

    return Wine(
      id: (rawDataMap['id'].runtimeType != String)?
        rawDataMap['id'].toString():
        rawDataMap['id'],
      name: rawDataMap['nome'],
      details: rawDataMap['dettagli'],
      imageFile: rawDataMap['url_immagine'],
      alcohol:  (rawDataMap['alcool'].runtimeType == double)?
        rawDataMap['alcool']:
        (rawDataMap['alcool'].runtimeType == int)?
          double.parse(rawDataMap['alcool'].toString()):
          null,
      temperature: (rawDataMap['temperatura_servizio'].runtimeType != double)?
        rawDataMap['temperatura_servizio'].toDouble():
        rawDataMap['temperatura_servizio'],
      minimumQuantity: rawDataMap['ordine_minimo'],
      priceInCents: (rawDataMap['prezzo_in_cents'].runtimeType == int)?
        rawDataMap['prezzo_in_cents']:
        0,
      year: (rawDataMap['anno'].runtimeType == int)?
        rawDataMap['anno']:
        null,
      containsSulfites: (rawDataMap['contiene_solfiti'].runtimeType == String)?
        stringToBool(rawDataMap['contiene_solfiti']):
        rawDataMap['contiene_solfiti'],
      volume_cc: rawDataMap['volume_cc'],
      producer: rawDataMap['produttore'],
      type: rawDataMap['tipo'],
      denominazione: rawDataMap['denominazione'],
    );
  }

  List<dynamic> formattedForCSV(){
    return [
      id,
      name,
      details,
      imageFile,
      alcohol,
      temperature,
      minimumQuantity,
      priceInCents,
      year,
      containsSulfites,
      volume_cc,
      producer,
      type,
      denominazione
    ];
  }

  Wine(
    {
      this.name = "",
      this.details = "",
      this.imageFile = "",
      this.alcohol,
      this.temperature = 0,
      this.id = "",
      this.minimumQuantity = 0,
      this.priceInCents = 0,
      this.year,
      this.containsSulfites = true,
      this.producer = "",
      this.volume_cc = 75,
      this.type = "",
      this.denominazione,
    }
  );

  @override
  String toString(){
    if (year != null){
      return name + '\n' + details + '\n' + year.toString() + '\n' + producer;
    }else{
      return name + '\n' + details + '\n' + producer;
    }
  }
}

void loadWineDatabaseFromCSV(File fileCSV) async {
  String winesDataCSV =  await fileCSV.readAsString();
  List<List<dynamic>> winesDataRaw = const CsvToListConverter(fieldDelimiter: ';').convert(winesDataCSV);

  // read the CSV header and remove it
  List<String> headerCSV = List<String>.from(winesDataRaw.first);
  winesDataRaw.removeAt(0);

  // converts the raw wines data into a list of maps, where the keys are the header names and the values the corresponding chracteristic of the wine
  wineList = [];
  for(List<dynamic> singleWineData in winesDataRaw){
    //try {
      wineList.add(Wine.fromList(headerCSV, singleWineData));
    //}catch(e){
      //debugPrint("Attenzione, problema cercando di caricare il database");
    //}
  }

  wineTypes = [];
  for (Wine wine in wineList){
    if (!wineTypes.contains(wine.type)){
      wineTypes.add(wine.type);
    }
  }
}

// creates a PDF containing one order (customer info and wines). It saves it on disk and opens a printing dialog
void printReceipt(Order order) async {
  final doc = pw.Document();

  debugPrint("[printReceipt] Creating file PDF...");
  doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Center(
          child: pw.Text(order.toString()),
        ); // Center
      }
    )
  );

  debugPrint("[printReceipt] Saving file...");
  Directory? appDocumentsDirectory;
  if (Platform.isAndroid) {
    appDocumentsDirectory = await getExternalStorageDirectory();
    if (appDocumentsDirectory != null){
      final file = File('${appDocumentsDirectory.path}/${DateTime.now().toString()}.pdf');
      await file.writeAsBytes(await doc.save());
      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => doc.save()
      );
    }else{
      debugPrint("Attenzione, impossibile salvare il pdf perché la directory della memoria esterna non é stata trovata!");
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Directory databaseDirectory = await getApplicationDocumentsDirectory();
  databaseDirectory = Directory('${databaseDirectory.parent.path}${Platform.pathSeparator}databases${Platform.pathSeparator}');
  databaseDirectory.create(recursive: false);

  debugPrint('${databaseDirectory.parent.path}${Platform.pathSeparator}databases${Platform.pathSeparator}');
  // Load estapp_database (quello con i vini) from asset and copy
  ByteData data = await rootBundle.load('assets${Platform.pathSeparator}databases${Platform.pathSeparator}estapp_database');
  List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

  await File(databaseDirectory.path + 'estapp_database').writeAsBytes(bytes);

  // Load swiss_addresses (quello con le citta e le strade) from asset and copy
  data = await rootBundle.load('assets${Platform.pathSeparator}databases${Platform.pathSeparator}swiss_addresses');
  bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

  // Save copied asset to documents
  await File(databaseDirectory.path + 'swiss_addresses').writeAsBytes(bytes);

  addressDatabase = await openDatabase('swiss_addresses');

  try {
    ordersDatabase = await openDatabase('orders_database');
  }catch (e){
    debugPrint("Errore aprendo il database 'orders_database': $e");
    // deletes the old orders database

    File file = File('databaseDirectory${Platform.pathSeparator}orders_database');
    file.deleteSync(recursive: true);
    try{
      debugPrint("Proviamo ad eliminare il database e a riaprirlo:");
      ordersDatabase = await openDatabase('orders_database');
    }catch(e){
      debugPrint("Ancora errore aprendo il database 'orders_database': $e");
    }
  }

  try{
    ordersDatabase.execute(
        "CREATE TABLE IF NOT EXISTS clienti(nome STRING, cognome STRING, citta STRING, strada STRING, numero_civico STRING, telefono STRING, email STRING, id STRING PRIMARY KEY);"
    );
  }catch(e){
    debugPrint("Errore creando la tabella 'clienti' nel database 'orders_database': $e");
  }

  try{
    ordersDatabase.execute(
        '''CREATE TABLE IF NOT EXISTS ordini(  
                                id STRING PRIMARY KEY,
                                id_cliente STRING,
                                sconto DECIMAL(3, 2),
                                FOREIGN KEY(id_cliente) REFERENCES clienti(id));'''
    );
  }catch(e){
    debugPrint("Errore creando la tabella 'ordini' nel database 'orders_database' rilevato: $e");
  }

  try{
    ordersDatabase.execute(
        '''CREATE TABLE IF NOT EXISTS vini_ordinati(  
                                      id STRING PRIMARY KEY, 
                                      id_vino STRING,
                                      quantita INTEGER, 
                                      id_ordine STRING,
                                      FOREIGN KEY(id_vino) REFERENCES catalogo_vini(id),
                                      FOREIGN KEY(id_ordine) REFERENCES ordini(id));'''
    );
  }catch(e){
    debugPrint("Errore creando la tabella 'vini_ordinati' nel database 'orders_database' rilevato: $e");
  }

  // gets the size of the screen
  screenWidth = MediaQueryData.fromWindow(WidgetsBinding.instance!.window).size.width;
  screenHeight = MediaQueryData.fromWindow(WidgetsBinding.instance!.window).size.width;
  sizes = AppSizes(screenWidth: screenWidth, screenHeight: screenHeight);

  // this class is used to save on disk a few key-value pairs, which in this case will contain the images folder path and the csv file with the database
  userPreferences = await SharedPreferences.getInstance();

  // tries to load the database that was used last time
  if (wineList.isEmpty){
    if (userPreferences.containsKey("wine_list_CSV_path")){
      File wineListCSV = File(userPreferences.getString("wine_list_CSV_path")!);
      loadWineDatabaseFromCSV(wineListCSV);
    }
  }
  if (imagesDirectory == null){
    if (userPreferences.containsKey("images_folder_path")){
      imagesDirectory = Directory(userPreferences.getString("images_folder_path")!);
      debugPrint("La directory delle immagini dell'ultima sessione é: ${imagesDirectory!.path}");
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DolceVino',
      theme: ThemeData(
        primarySwatch: Colors.grey,
      ),
      home: const MyHomePage(title: 'DolceVino'),
    );
  }
}

class WineTypesMenu extends StatefulWidget{
  final ValueChanged? onTypeSelected;
  final List<String> wineTypes;
  final Directory? imagesDirectory;

  const WineTypesMenu(
    {
      Key? key,
      this.onTypeSelected,
      required this.wineTypes,
      this.imagesDirectory,
    }
  ):super(key: key);

  @override
  State<WineTypesMenu> createState() => WineTypesMenuState();
}

class WineTypesMenuState extends State<WineTypesMenu>{
  TextStyle textStyle = TextStyle(
      fontSize: 40,
      foreground: Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 20),
          const Offset(150, 20),
          <Color>[
            Colors.white,
            Colors.white,
          ],
        )
  );

  @override
  Widget build(BuildContext context){
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: widget.wineTypes.length,
      itemBuilder: (BuildContext context, int index) {
        return SizedBox(
          width: 300,
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: Stack(
              children: <Widget> [
                if(widget.imagesDirectory != null)...[
                  Image.file(File(widget.imagesDirectory!.path + Platform.pathSeparator + widget.wineTypes[index] + '.jpg'))
                ],
                if(widget.imagesDirectory == null)...[
                  Image.asset("assets/images/wine_image_not_found.jpg")
                ],
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: (){
                        String wineType = widget.wineTypes[index];
                        widget.onTypeSelected?.call(wineType);
                      },
                    )
                  )
                )
              ]
            )
          )
        );
      },
      separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 20));
  }
}

class WineList extends StatefulWidget{
  final Directory? imagesDirectory;
  final Order order;
  final List<Wine> wines;
  final ValueChanged? onAddButtonPressed;
  final ValueChanged? onRemoveButtonPressed;

  const WineList(
    {
      Key? key,
      this.wines = const [],
      required this.order,
      this.onAddButtonPressed,
      this.onRemoveButtonPressed,
      this.imagesDirectory,
    }):super(key: key);

  @override
  State<WineList> createState() => WineListState();
}

class WineListState extends State<WineList>{

  @override
  Widget build(BuildContext context){
    debugPrint("WineList rebuild triggered");
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 20.0),
      scrollDirection: Axis.vertical,
      itemCount: widget.wines.length,
      itemBuilder: (BuildContext context, int index) {
        Wine wine = widget.wines[index];
        return Card(
          elevation: 8,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Column(
                children: [
                  SizedBox(
                      height: sizes.wineImage.height,
                      width:sizes.wineImage.width,
                      child: (widget.imagesDirectory != null)?
                      Image.file(File(widget.imagesDirectory!.path + Platform.pathSeparator + wine.imageFile)):
                      Image.asset("assets/images/wine_image_not_found.jpg")
                  ),
                  Text(
                    "${(wine.priceInCents * 0.01).toStringAsFixed(2)} CHF",
                    textAlign: TextAlign.left,
                    overflow: TextOverflow.fade,
                    style: TextStyle(
                      fontSize: sizes.textLarge.shortestSide,
                      color: Colors.black54,
                    ),
                  ),
                ]
              ),
              Expanded(
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          flex: 4,
                          fit: FlexFit.tight,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: sizes.wineImage.height),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  wine.name,
                                  textAlign: TextAlign.left,
                                  overflow: TextOverflow.fade,
                                  style: TextStyle(
                                    fontSize: sizes.wineName.shortestSide,
                                    color: Colors.black54,
                                  ),
                                ),
                                if (wine.details != "")...[
                                  Text(
                                    wine.details,
                                    style: TextStyle(
                                      fontSize: sizes.producerName.shortestSide,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                                Text(
                                  wine.producer,
                                  overflow: TextOverflow.fade,
                                  style: TextStyle(
                                    fontSize: sizes.description.shortestSide,
                                    color: Colors.black54,
                                  ),
                                ),
                              ]
                            )
                          ),
                        ),
                        Flexible(
                          flex: 1,
                          fit: FlexFit.tight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                "${widget.order.amountOf(wine)}",
                                style: TextStyle(
                                  fontSize: sizes.bottleNumber.shortestSide,
                                  color: Colors.black54,
                                )
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    fixedSize: Size(
                                        sizes.addRemoveButtons.width,
                                        sizes.addRemoveButtons.height
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5.0),
                                    ),
                                    primary: Colors.grey.shade400
                                ),
                                child: const Icon(Icons.add),
                                onPressed: () {
                                  widget.onAddButtonPressed?.call(wine);
                                },
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    fixedSize: Size.copy(sizes.addRemoveButtons),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5.0),
                                    ),
                                    primary: Colors.grey.shade300
                                ),
                                child: Icon(
                                  Icons.remove,
                                  size: sizes.addRemoveButtons.shortestSide,
                                ),
                                onPressed: () {
                                  widget.onRemoveButtonPressed?.call(wine);
                                },
                              ),
                            ]
                          )
                        )
                      ]
                    ),
                    Row(
                      children: <Widget>[
                        Flexible(
                          flex: 4,
                          fit: FlexFit.tight,
                          child: Row(
                            children: <Widget>[
                              if (wine.alcohol != null)...[
                                SizedBox(
                                  child: Row(
                                    children: <Widget>[
                                      Icon(Icons.wine_bar, size: sizes.icons.shortestSide),
                                      Text("${wine.alcohol}%")
                                    ]
                                  ),
                                ),
                              ],
                              if (wine.year != null)...[
                                SizedBox(width: sizes.icons.shortestSide * 0.5),
                                SizedBox(
                                  child: Row(
                                      children: <Widget>[
                                        Icon(Icons.calendar_today_outlined, size: sizes.icons.shortestSide),
                                        Text(wine.year.toString())
                                      ]
                                  ),
                                ),
                              ],
                              SizedBox(width: sizes.icons.shortestSide * 0.5),
                              SizedBox(
                                child: Row(
                                  children: <Widget>[
                                    Icon(Icons.thermostat, size: sizes.icons.shortestSide),
                                    Text("${wine.temperature}°C")
                                  ]
                                )
                              ),
                              if (wine.containsSulfites)...[
                                SizedBox(width: sizes.icons.shortestSide * 0.5),
                                SizedBox(
                                    child: Row(
                                        children: <Widget>[
                                          Icon(Icons.science_sharp, size: sizes.icons.shortestSide),
                                          const Text("Avec sulfites")
                                        ]
                                    )
                                ),
                              ],
                              if (!wine.containsSulfites)...[
                                SizedBox(width: sizes.icons.shortestSide * 0.5),
                                SizedBox(
                                    child: Row(
                                        children: <Widget>[
                                          Icon(Icons.science_outlined, size: sizes.icons.shortestSide),
                                          const Text("Sans sulfites")
                                        ]
                                    )
                                ),
                              ],
                              if (wine.denominazione != null)...[
                                SizedBox(width: sizes.icons.shortestSide * 0.5),
                                Text(wine.denominazione!),
                              ],
                              SizedBox(width: sizes.icons.shortestSide * 0.5),
                              Text("${wine.volume_cc} cc",
                                style: TextStyle(
                                  fontSize: sizes.textSmall.shortestSide,
                                ),
                                textAlign: TextAlign.end,
                              )
                            ]
                          )
                        ),
                        if(widget.order.amountOf(wine) > 0)...[
                          Flexible(
                            flex: 1,
                            fit: FlexFit.tight,
                            child: Text(
                              (widget.order.amountOf(wine) * wine.priceInCents * 0.01).toStringAsFixed(2),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: sizes.price.shortestSide,
                                color: Colors.black54,
                              )
                            ),
                          ),
                        ]
                      ]
                    )
                  ]
                )
              )
            ]
          )
        );
      },
      separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 20));
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool shoppingCartIsCollapsed = true;
  String? selectedWineType;
  Order currentOrder = Order();
  List<Order> ordersList = [];

  @override
  void dispose(){
    addressDatabase.close();
    ordersDatabase.close();
    super.dispose();
  }

  void saveOrdersToCSV() async {
    List<List<dynamic>> winesListForCSV = [];
    List<List<dynamic>> clientsListForCSV = [];
    List<List<dynamic>> ordersListForCSV = [];

    // here it finds the "files" directory and creates the correct path
    Directory appDocumentsDirectory;
    try {
      if (Platform.isAndroid){
        appDocumentsDirectory = await getExternalStorageDirectory() ?? Directory.current;
        // se é il primo ordine ripulisce la cartella dai vecchi files
        if (ordersList.length == 1){
          appDocumentsDirectory.deleteSync(recursive: true);
          await appDocumentsDirectory.create(recursive: true);
        }
      }else{
        debugPrint("Attenzione, su IOs la gestione delle directory é diversa e non salva i files csv");
        return;
      }
    }catch(e){
      debugPrint("Errore cercando di ottenere la directory dei documenti. $e");
      return;
    }
    String timeSignature = "${DateTime.now().year}_${DateTime.now().month}_${DateTime.now().day}_${DateTime.now().second}";
    String appDocumentsPath = appDocumentsDirectory.path + Platform.pathSeparator;
    File clientiFile = File('${appDocumentsPath}clienti_${timeSignature}.csv');
    File viniOrdinatiFile = File('${appDocumentsPath}vini_ordinati_${timeSignature}.csv');
    File ordiniFile = File('${appDocumentsPath}ordini_${timeSignature}.csv');
    // here it takes the data from all orders (wines, clients) and formats it to be saved in a CSV file.
    // In the end it will create 3 different CSV files: clienti.csv, vini_ordinati.csv, ordini.csv


    clientsListForCSV.add(Client.headerNamesCSV);
    winesListForCSV.add(Wine.headerNamesCSV + ['quantita_ordinata', 'id_ordine']);
    ordersListForCSV.add(['id', 'id_cliente', 'sconto']);

    for (Order order in ordersList){
      // formatta i dati dei vini ordinati
      order.wines.forEach((wine, amount)=> winesListForCSV.add(wine.formattedForCSV() + [amount, order.id]));
      // format data of the clients
      clientsListForCSV.add(order.client.formattedForCSV());
      // format data of the orders
      ordersListForCSV.add([order.id, order.client.id, order.discount]);
    }

    // saves the csv files
    try {
      debugPrint("Directory dove salcare i file: ${appDocumentsPath}");
      debugPrint(const ListToCsvConverter(fieldDelimiter: ';').convert(clientsListForCSV));

      clientiFile.writeAsString(const ListToCsvConverter(fieldDelimiter: ';').convert(clientsListForCSV));
      viniOrdinatiFile.writeAsString(const ListToCsvConverter(fieldDelimiter: ';').convert(winesListForCSV));
      ordiniFile.writeAsString(const ListToCsvConverter(fieldDelimiter: ';').convert(ordersListForCSV));
    }catch(e){
      debugPrint("Errore cercando di salvare gli ordini in formato CSV nella directory $appDocumentsPath\n$e");
    }
  }

  void openClientInfoForm(){
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black12.withOpacity(0.6), // Background color
      barrierDismissible: false,
      barrierLabel: 'Dialog',
      transitionDuration: const Duration(milliseconds: 400), // How long it takes to popup dialog after button click
      pageBuilder: (context, __, ___) {
        // Makes widget fullscreen
        return Scaffold(
            body: SizedBox.expand(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                          height: 100,
                          alignment: Alignment.centerLeft,
                          child: SizedBox.square(
                              dimension: 100,
                              child: Center(
                                child: FloatingActionButton(
                                  onPressed: () {
                                    FocusManager.instance.primaryFocus?.unfocus(); // closes the keyboard
                                    Navigator.pop(context, true);
                                  },
                                  backgroundColor: Colors.grey,
                                  child: const Icon(Icons.arrow_back),
                                ),
                              )
                          )
                      ),
                      ClientInformationForm(
                        onClose: (){
                          setState(() {
                            shoppingCartIsCollapsed = true;
                          });
                        },
                        onSaved: (Client clientInfo) async {
                          setState(() {
                            currentOrder.client = clientInfo;
                            ordersList.add(currentOrder);
                            currentOrder = Order();
                          });
                          debugPrint(ordersList.last.toString());
                          saveOrdersToCSV();
                          printReceipt(ordersList.last);
                        },
                      ),
                    ],
                  ),
                )
            )
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (selectedWineType == null){
      if (wineTypes.isNotEmpty){
        selectedWineType = wineTypes.first;
      }
    }
    AppBar appBar = AppBar(
      title: Text(widget.title),
    );
    debugPrint("MyHomePage rebuild triggered");
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: appBar,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blueGrey,
              ),
              child: Text('DolceVino'),
            ),
            ListTile(
              title: const Text('Carica database vini'),
              onTap: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(dialogTitle: "Seleziona il database dei vini");
                if (result != null) {
                  try {
                    File file = File(result.files.single.path!);
                    loadWineDatabaseFromCSV(file);
                    // stores the path of the selected file on disk
                    userPreferences.setString("wine_list_CSV_path", file.path);
                  }catch(e){
                    debugPrint("Errore cercando di aprire il file selezionato dall'utente!\n$e");
                  }
                } else {
                  throw("Error cercando di aprire il file selezionato dall'utente!");
                }
              },
            ),
            ListTile(
              title: const Text('Seleziona cartella immagini'),
              onTap: () async {
                String? selectedDirectory = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Seleziona la cartella con le immagini dei vini');

                if (selectedDirectory == null) {
                  debugPrint("Attenzione, nessuna cartella selezionata!");
                }else{
                  setState(() {
                    imagesDirectory = Directory(selectedDirectory);
                  });
                  // stores the path of the selected images directory on disk
                  userPreferences.setString("images_folder_path", selectedDirectory);
                }
              },
            ),
            ListTile(
              title: const Text('Controlla ordini'),
              onTap: () {
                showGeneralDialog(
                  context: context,
                  barrierColor: Colors.black12.withOpacity(0.6), // Background color
                  barrierDismissible: true,
                  barrierLabel: 'Dialog',
                  transitionDuration: const Duration(milliseconds: 400), // How long it takes to popup dialog after button click
                  pageBuilder: (context, __, ___) {
                    return Scaffold(
                      body: SizedBox.expand(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                flex: 1,
                                child: FloatingActionButton(
                                  onPressed: () {
                                    FocusManager.instance.primaryFocus?.unfocus(); // closes the keyboard
                                    Navigator.pop(context, true);
                                  },
                                  backgroundColor: Colors.grey,
                                  child: const Icon(Icons.arrow_back),
                                ),
                              ),
                              Expanded(
                                flex: 10,
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 20.0),
                                  scrollDirection: Axis.vertical,
                                  itemCount: ordersList.length,
                                  itemBuilder: (BuildContext context, int index) {
                                    Order order = ordersList[index];
                                    List<ListTile> wines = [];
                                    for (Wine wine in order.wines.keys){
                                      ListTile wineTile = ListTile(
                                        title: Text(wine.name),
                                        subtitle: (wine.year != null)?
                                          Text(wine.producer + ', ' + wine.year.toString()):
                                          Text(wine.producer),
                                        leading: (imagesDirectory != null)?
                                          Image.file(File(imagesDirectory!.path + Platform.pathSeparator + wine.imageFile)):
                                          Image.asset("assets/images/wine_image_not_found.jpg"),
                                        trailing: Text("x ${order.wines[wine]}"),
                                      );
                                      wines.add(wineTile);
                                    }
                                    return Card(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(order.client.fullName),
                                          Text(order.client.address),
                                          Text(order.client.telephoneNumber),
                                          Text(order.client.email),
                                          Text("Totale ordine: " + (order.totalPriceCents * 0.01).toStringAsFixed(2)),
                                          if(order.discount != 0) ...[
                                            Text("Con sconto del ${order.discount * 100}%: "+ (order.totalPriceCents * 0.01 * (1-order.discount)).toStringAsFixed(2))
                                          ],
                                          ExpansionTile(
                                            title: Row(
                                              children: const <Widget> [
                                                Icon(Icons.arrow_drop_down_sharp),
                                                Text('Vini ordinati'),
                                              ]
                                            ),
                                            children: wines,
                                          )
                                        ]
                                      )
                                    );
                                  },
                                  separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 20)
                                )
                              )
                            ]
                          )
                        )
                      )
                    );
                  }
                );
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              flex: 1,
              //padding: const EdgeInsets.fromLTRB(0.0, 20, 0.0, 20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 20, 20.0, 20.0),
                child: WineTypesMenu(
                  wineTypes: wineTypes,
                  imagesDirectory: imagesDirectory,
                  onTypeSelected:(value){
                    String wineType = value as String;
                    if (wineTypes.contains(wineType)){
                      setState((){
                        selectedWineType = wineType;
                      });
                    }else{
                      throw("Attenzione! Selezionato un tipo di vino che non é stato caricato dal database!");
                    }
                  },
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: WineList(
                imagesDirectory: imagesDirectory,
                order: currentOrder,
                wines: wineList.where((wine) => wine.type == selectedWineType).toList(),
                onAddButtonPressed: (wine){
                  setState(() {
                    currentOrder.addBottles(wine);
                  });
                },
                onRemoveButtonPressed: (wine){
                  setState(() {
                    currentOrder.removeBottles(wine);
                  });
                },
              )
            ),
            ShoppingCart(
              imagesDirectory: imagesDirectory,
              maxHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).viewInsets.bottom - appBar.preferredSize.height - MediaQuery.of(context).padding.top,
              collapsed: shoppingCartIsCollapsed,
              order: currentOrder,
              onDeleteButtonPressed: (wineToDelete){
                setState(() {
                  currentOrder.removeWine(wineToDelete);
                });
              },
              onConfirmButtonPressed: (){
                openClientInfoForm();
              },
              onExpandButtonPressed: (){
                setState(() {
                  shoppingCartIsCollapsed = false;
                });
              },
              onCollapseButtonPressed: (){
                setState(() {
                  shoppingCartIsCollapsed = true;
                });
              },
              onDiscountApplied: (double discount){
                setState(() {
                  currentOrder.discount = discount;
                });
              },
            )
          ],
        ),
      )
    );
  }
}

class ShoppingCart extends StatefulWidget {
  final bool collapsed;
  final Order order;
  final ValueChanged? onDeleteButtonPressed;
  final VoidCallback? onConfirmButtonPressed;
  final VoidCallback? onCollapseButtonPressed;
  final VoidCallback? onExpandButtonPressed;
  final ValueChanged<double>? onDiscountApplied;
  final double? maxHeight;
  final Directory? imagesDirectory;

  const ShoppingCart({
    Key? key,
    required this.order,
    this.onDeleteButtonPressed,
    this.onConfirmButtonPressed,
    this.collapsed = true,
    this.onCollapseButtonPressed,
    this.onExpandButtonPressed,
    this.onDiscountApplied,
    this.maxHeight,
    this.imagesDirectory,
  }) : super(key: key);

  @override
  ShoppingCartState createState() => ShoppingCartState();
}

class ShoppingCartState extends State<ShoppingCart> {
  double collapsedHeight = 100, collapsedWidth = 100;
  double pictureHeight = 50, pictureWidth = 50, shoppingCartIconHeight = 50;
  Color rabaisTextFieldColor = Colors.white;
  TextEditingController discountTextFieldController = TextEditingController();

  @override
  void dispose() {
    discountTextFieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("MyHomePage rebuild triggered");
    debugPrint("Size: ${MediaQuery.of(context).size.toString()}");
    debugPrint("WiewInsets: ${MediaQuery.of(context).viewInsets.bottom}");
    debugPrint("Padding: ${MediaQuery.of(context).padding}");
    Size contextSize = MediaQuery.of(context).size;
    List<Wine> wineList = widget.order.wines.keys.toList();
    List<Widget> winePictures = [];
    List<Widget> widgetList = [];

    SizedBox shoppingCartIcon = SizedBox(
        width: collapsedWidth - 10,
        height: collapsedHeight - 10,
        child: Icon(Icons.shopping_cart, size: shoppingCartIconHeight, color: Colors.grey));

    // creates list of Images
    for (Wine wine in wineList) {
      Widget winePicture = Card(
        clipBehavior: Clip.antiAlias,
        child: (widget.imagesDirectory != null)?
          Image.file(
            File(widget.imagesDirectory!.path + Platform.pathSeparator + wine.imageFile),
            height: pictureHeight,
            width: pictureWidth
          ):
          Image.asset(
            "assets/images/wine_image_not_found.jpg",
            height: pictureHeight,
            width: pictureWidth
          )
      );
      winePictures.add(winePicture);
    }

    widgetList.add(shoppingCartIcon);
    widgetList.add(Wrap(direction: Axis.horizontal, spacing: 5, children: winePictures));

    return AnimatedContainer(
      duration: const Duration(milliseconds:200),
      width: double.infinity,
      height: (widget.collapsed) ? 100 : widget.maxHeight ?? contextSize.height * 0.7,
      padding: const EdgeInsets.fromLTRB(30, 15.0, 30, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.6),
            spreadRadius: 5,
            blurRadius: 6,
            //offset: const Offset(0, 3), // changes position of shadow
          ),
        ],
      ),
      child: AnimatedCrossFade(
        crossFadeState: (widget.collapsed) ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        duration: const Duration(milliseconds: 300),
        firstChild: Align(
            alignment: Alignment.center,
            child: Card(
                elevation: 15,
                child: Material(
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8))),
                    color: Colors.white,
                    child: InkWell(
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(10.0, 5, 10, 5),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start, children: widgetList
                          )
                      ),
                      onTap: (){
                        widget.onExpandButtonPressed?.call();
                      },
                    )
                )
            )
        ),
        secondChild: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              flex: 1,
              child: Row(children:[
                IconButton(
                    tooltip: "Close",
                    icon: const Icon(Icons.arrow_drop_down_sharp, size: 35),
                    onPressed: () {
                      widget.onCollapseButtonPressed?.call();
                    }
                )
              ]
              ),
            ),
            Flexible(
              flex: 10,
              child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 20.0),
                  scrollDirection: Axis.vertical,
                  itemCount: widget.order.numberOfWines,
                  itemBuilder: (BuildContext context, int index) {
                    Wine wine = widget.order.wines.keys.elementAt(index);
                    return Row(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          IconButton(
                              icon: const Icon(Icons.remove_circle, size: 20),
                              onPressed: (){setState(() {
                                widget.onDeleteButtonPressed?.call(wine);
                              });}
                          ),
                          if(widget.imagesDirectory != null)...[
                            Image.file(
                              File(widget.imagesDirectory!.path + Platform.pathSeparator + wine.imageFile),
                              width: sizes.shoppingCartImage.width,
                              height: sizes.shoppingCartImage.height,
                            )
                          ],
                          if(widget.imagesDirectory == null)...[
                            Image.asset(
                              "assets/images/wine_image_not_found.jpg",
                              width: sizes.shoppingCartImage.width,
                              height: sizes.shoppingCartImage.height,
                            )
                          ],
                          Expanded(
                            flex: 2,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: sizes.shoppingCartImage.height),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                      "x ${widget.order.amountOf(wine)}",
                                      style: TextStyle(fontSize: sizes.textSmall.shortestSide)
                                  ),
                                  Text(
                                      wine.name,
                                      style: TextStyle(fontSize: sizes.shoppingCartName.shortestSide, fontWeight: FontWeight.bold)
                                  ),
                                  if (wine.year != null)...[
                                    Row(
                                      children:[
                                        SizedBox(width: sizes.icons.width*0.5),
                                        Icon(Icons.calendar_today, size: sizes.icons.width),
                                        Text(wine.year.toString())
                                      ]
                                    )
                                  ]
                                ]
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Text(
                                      "x ${(wine.priceInCents * 0.01).toStringAsFixed(2)} CHF",
                                      style: TextStyle(fontSize: sizes.textSmall.shortestSide)
                                  )
                                ]
                            ),
                          ),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: <Widget> [
                                    Text(
                                        (wine.priceInCents * 0.01 * widget.order.amountOf(wine)).toStringAsFixed(2),
                                        style: TextStyle(fontSize: sizes.textSmall.shortestSide, fontWeight: FontWeight.bold)
                                    )
                                  ]
                              )
                          )
                        ]
                    );
                  },
                  separatorBuilder: (BuildContext context, int index) => const Divider(color: Colors.grey)
              ),
            ),
            const Divider(color: Colors.grey),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                    width: sizes.shoppingCartImage.width + 20
                ),
                const Spacer(
                    flex: 2
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "TOTAL",
                          style: TextStyle(
                            fontSize: sizes.shoppingCartName.shortestSide,
                            fontWeight: FontWeight.bold,
                            decoration: (widget.order.discount!=0)?TextDecoration.lineThrough:null,
                          ),
                        ),
                        if (widget.order.discount!=0) ...[
                          Text(
                            "- ${widget.order.discount*100}%",
                            style: TextStyle(
                              fontSize: sizes.shoppingCartName.shortestSide,
                              fontWeight: FontWeight.bold,
                            )
                          )
                        ]
                      ],
                    )
                  )
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Column(
                      children: <Widget> [
                        Text(
                          (widget.order.totalPriceCents * 0.01).toStringAsFixed(2),
                          style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              decoration: (widget.order.discount!=0) ? TextDecoration.lineThrough: null
                          )
                        ),
                        if (widget.order.discount!=0) ...[
                          Text(
                              (widget.order.totalPriceCents * 0.01 * (1-widget.order.discount)).toStringAsFixed(2),
                              style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                              )
                          )
                        ]
                      ]
                    )
                  )
                ),
              ]
            ),
            Flexible(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                  child:  Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    SizedBox( //------------------- DISCOUNT TEXT FIELD
                      width: contextSize.width * 0.3,
                      child: TextField(
                        controller: discountTextFieldController,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: rabaisTextFieldColor,
                          border: const OutlineInputBorder(),
                          hintText: 'Code de rabais',
                          labelText: 'Code de rabais',
                        ),
                        onChanged: (String? value) {
                          if (discountCodes.containsKey(value)) {
                            widget.onDiscountApplied?.call(
                                discountCodes[value]!);
                            setState(() {
                              rabaisTextFieldColor = Colors.lightGreen.shade50;
                            });
                          } else {
                            widget.onDiscountApplied?.call(0.0);
                            setState(() {
                              rabaisTextFieldColor = Colors.transparent;
                            });
                          }
                        },
                      )
                    ),
                    ElevatedButton(
                      child: const Text("Confirmer"),
                      onPressed: () {
                        setState(() {
                          discountTextFieldController.text = "";
                        });
                        widget.onConfirmButtonPressed?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        fixedSize: Size(contextSize.width * 0.3, 70),
                        primary: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                              width: 2.0, color: Colors.grey.shade50),
                        )
                      )
                    )
                  ]
                )
              ),
            )
          ]
        ),
      )
    );
  }
}

class ClientInformationForm extends StatefulWidget{
  final VoidCallback? onClose;
  final ValueChanged<Client>? onSaved;
  static const double _greetingsImageScaleFactor = 0.4;

  const ClientInformationForm(
      {
        Key? key,
        this.onClose,
        this.onSaved,
      }): super(key: key);

  @override
  State<ClientInformationForm> createState() => ClientInformationFormState();

}

class ClientInformationFormState extends State<ClientInformationForm>{
  final _formKey = GlobalKey<FormState>();
  Client client = Client();
  TextEditingController cityTextController = TextEditingController();
  TextEditingController streetTextController = TextEditingController();
  TextEditingController streetNumberTextController = TextEditingController();
  TextEditingController discountTextController = TextEditingController();
  Color discountTextFieldColor = Colors.white;
  String buttonText = "JE N'AI PAS DE CODE";

  @override
  void dispose() {
    cityTextController.dispose();
    streetTextController.dispose();
    streetNumberTextController.dispose();
    discountTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
        color: Colors.transparent,
        child: Padding(
            padding: const EdgeInsets.fromLTRB(100, 0, 100, 0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  TextFormField(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: const InputDecoration(
                      icon: Icon(Icons.person),
                      hintText: 'Rentrez votre nom',
                      labelText: 'Nom *',
                    ),
                    onSaved: (String? value) {
                      client.name = value ?? "";
                    },
                    validator: (String? value) {
                      bool invalid =  (value != null && !RegExp(r'^[\u00BF-\u1FFF\u2C00-\uD7FFa-zA-Z\s\-]+$').hasMatch(value))||
                                      (value == null);
                      if (invalid){
                        return 'Le nom n\'est pas valable';
                      }else{
                        null;
                      }
                    },
                  ),
                  TextFormField(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: const InputDecoration(
                      icon: Icon(Icons.person),
                      hintText: 'Rentrez votre nom de famille',
                      labelText: 'Nom de famille*',
                    ),
                    onSaved: (String? value) {
                      client.surname = value ?? "";
                    },
                    validator: (String? value) {
                      bool invalid =  (value != null && !RegExp(r'^[\u00BF-\u1FFF\u2C00-\uD7FFa-zA-Z\s\-]+$').hasMatch(value))||
                          (value == null);
                      if (invalid){
                        return 'Le nom n\'est pas valable';
                      }else{
                        null;
                      }
                    },
                  ),
                  TextFormField(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: const InputDecoration(
                      icon: Icon(Icons.local_phone),
                      hintText: 'Numéro de telephone',
                      labelText: 'Telephone *',
                    ),
                    onSaved: (String? value) {
                      client.telephoneNumber = value ?? "";
                    },
                    validator: (String? value) {
                      bool invalid =  (value != null && value.contains(RegExp(r'\D'))) ||
                                      (value == "");
                      if (invalid){
                        return 'Numéro pas valable';
                      }else{
                        null;
                      }
                    },
                  ),
                  TextFormField(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      icon: Icon(Icons.email),
                      hintText: 'Addresse email',
                      labelText: 'Mail *',
                    ),
                    onSaved: (String? value) {
                      client.email = value ?? "";
                    },
                    validator: (String? value) {
                      bool invalid =  (value != null && ( !value.contains('@') ||
                                                          !value.contains('.')) );
                      if (invalid){
                        return null;
                      }else{
                        return null;
                      }
                    },
                  ),
                  FormField<String>(
                    builder: (FormFieldState<String> state){
                      return AddressAutocomplete(
                        cityTextController: cityTextController,
                        streetTextController: streetTextController,
                        streetNumberTextController: streetNumberTextController,
                      );
                    },
                    onSaved: (String? value){
                      client.city = cityTextController.text;
                      client.street = streetTextController.text;
                      client.streetNumber = streetNumberTextController.text;
                    },
                  ),
                  SizedBox(
                    height: 100,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                          onPressed: () {
                           if(_formKey.currentState!.validate()){
                             _formKey.currentState?.save();
                             debugPrint("The saved client data is: ${client.toString()}");
                              showGeneralDialog(
                                context: context,
                                barrierColor: Colors.black12.withOpacity(0.6), // Background color
                                barrierDismissible: true,
                                barrierLabel: 'Dialog',
                                transitionDuration: const Duration(milliseconds: 400), // How long it takes to popup dialog after button click
                                pageBuilder: (_, __, ___) {
                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                        onTap: (){
                                          widget.onSaved?.call(client);
                                          widget.onClose?.call();   // when the userInfo form closes, it calls a callback, in this case it closes the shopping cart
                                          Navigator.pop(context, true);
                                          Navigator.pop(context, true);
                                        },
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: <Widget> [
                                            LayoutBuilder(
                                              builder: (BuildContext context, BoxConstraints constraints){
                                                double greetingsWidth, greetingsHeight, smallerDimension;
                                                smallerDimension = min(constraints.maxWidth, constraints.maxHeight);
                                                greetingsWidth = max(smallerDimension*0.5, constraints.minWidth);
                                                greetingsHeight = max(smallerDimension*0.5, constraints.minHeight);
                                                return SizedBox(
                                                  height: greetingsHeight,
                                                  width: greetingsWidth,
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(10.0),
                                                    child: Stack(
                                                      children: <Widget> [
                                                        Column(
                                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                                            children: <Widget> [
                                                              const Expanded(
                                                                  flex: 1,
                                                                  child: Material(
                                                                      elevation: 30,
                                                                      color: Colors.blueGrey
                                                                  )
                                                              ),
                                                              Expanded(
                                                                  flex: 2,
                                                                  child: Material(
                                                                      elevation: 5,
                                                                      color: Colors.white,
                                                                      child: Center(
                                                                        child: Column(
                                                                          mainAxisSize: MainAxisSize.min,
                                                                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                                          children: [
                                                                            Text(
                                                                                "MERCI POUR VOS ACHATS!",
                                                                                style: TextStyle(
                                                                                  fontWeight: FontWeight.bold,
                                                                                  fontSize: sizes.thanksMessage.shortestSide,
                                                                                )
                                                                            ),
                                                                          ]
                                                                        )
                                                                      )
                                                                  )
                                                              ),
                                                            ]
                                                        ),
                                                        Positioned(
                                                          top: greetingsHeight * (0.3 - ClientInformationForm._greetingsImageScaleFactor*0.5),
                                                          left: greetingsWidth* (0.5 - ClientInformationForm._greetingsImageScaleFactor*0.5),
                                                          child: Image.asset(
                                                              "assets/images/greetingsImage.png",
                                                              width: greetingsWidth * ClientInformationForm._greetingsImageScaleFactor,
                                                              height: greetingsHeight * ClientInformationForm._greetingsImageScaleFactor
                                                          )
                                                        ),
                                                      ]
                                                    )
                                                  ),
                                                );
                                              }
                                            )
                                          ]
                                        )
                                    )
                                  );
                                }
                              );
                            }else{
                              const snackBar = SnackBar(
                                content: Center(
                                  widthFactor: 1,
                                  heightFactor: 1,
                                  child: Text('Remplissez correctement toutes les cases!'),
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.red,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(snackBar);
                            }
                          },
                          style: ButtonStyle(
                            elevation: MaterialStateProperty.all<double>(15.0),
                            minimumSize: MaterialStateProperty.all<Size>(const Size(0, 60)),
                            backgroundColor: MaterialStateProperty.all<Color>(Colors.grey),
                            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                              RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                              )
                            )
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const <Widget> [
                              Text('SOUMETTRE L\'ORDRE'),
                              Icon(Icons.arrow_forward),
                            ]
                          )
                      ),
                    )
                  )
                ]
              )
            )
        )
    );
  }
}

class AddressAutocomplete extends StatefulWidget{
  final TextEditingController cityTextController;
  final TextEditingController streetTextController;
  final TextEditingController streetNumberTextController;

  const AddressAutocomplete(
    {
      Key? key,
      required this.streetTextController,
      required this.cityTextController,
      required this.streetNumberTextController,
    }
  ) : super(key: key);

  @override
  State<AddressAutocomplete> createState() => AddressAutocompleteState();
}

class AddressAutocompleteState extends State<AddressAutocomplete> {
  bool showSuggestions = false;
  List<String> suggestedMunicipalities = [];
  List<String> suggestedStreets = [];
  String selectedMunicipality = "", selectedStreet = "";
  static const int maxSuggestions = 10;

  List<String> findBestSuggestions(List<Map<String, Object?>> queryResult, String incompleteName){
    List<NameSuggestion> bestSuggestions = [];
    List<String> bestNames = [];
    for (Map<String, Object?> returnedRow in queryResult) {
      String suggestionFullName = returnedRow['name'] as String;
      String suggestion;
      double similarityScore;

      suggestion = suggestionFullName.toLowerCase();
      if (suggestion.length > incompleteName.length){
        suggestion = suggestion.substring(0, incompleteName.length);
      }

      similarityScore = incompleteName.toLowerCase().similarityTo(suggestion);
      if (bestSuggestions.length < maxSuggestions){
        bestSuggestions.add(NameSuggestion(suggestionFullName, similarityScore));
      }else{
        if(bestSuggestions.length == maxSuggestions){
          bestSuggestions.sort((a, b)=> (b.similarityScore.compareTo(a.similarityScore)));
        }
        if (similarityScore > bestSuggestions.last.similarityScore){
          bestSuggestions.removeLast();
          bestSuggestions.add(NameSuggestion(suggestionFullName, similarityScore));

        }
        bestSuggestions.sort((a, b)=> (b.similarityScore.compareTo(a.similarityScore)));
      }
    }

    for (NameSuggestion suggestion in bestSuggestions){
      //debugPrint('Full name: ${suggestion.name}  Similarity: ${suggestion.similarityScore}');
      bestNames.add(suggestion.name);
    }
    return bestNames;
  }


  Future<List<String>> getSuggestedMunicipality (String incompleteName) async {
    List<Map<String, Object?>> queryResult;

    queryResult = await addressDatabase.rawQuery('''
      SELECT DISTINCT name FROM municipalities WHERE name LIKE '$incompleteName%'
      LIMIT 15;
    '''
    );

    if (queryResult.isEmpty){
      queryResult = await addressDatabase.rawQuery('''
        SELECT DISTINCT name FROM municipalities;
      '''
      );
    }

    return findBestSuggestions(queryResult, incompleteName);
  }

  Future<List<String>> getSuggestedStreet (String incompleteName) async {
    List<Map<String, Object?>> queryResult;

    queryResult = await addressDatabase.rawQuery('''
      SELECT DISTINCT name FROM streets WHERE name LIKE '$incompleteName%'
      AND postal_code_and_municipality LIKE '%$selectedMunicipality%'
      LIMIT 15;
      '''
    );

    if (queryResult.isEmpty) {
      queryResult = await addressDatabase.rawQuery('''
        SELECT DISTINCT name FROM streets WHERE name LIKE '${incompleteName[0]}%'
        AND postal_code_and_municipality LIKE '%$selectedMunicipality%'
        '''
      );
    }
    return findBestSuggestions(queryResult, incompleteName);
  }

  @override
  Widget build(BuildContext context){
    return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AutocompleteList(
              labelText: "Ville *",
              hintText: "Ville",
              suggestions: suggestedMunicipalities,
              textController: widget.cityTextController,
              onChangedCallback: (incompleteName)async{
                suggestedMunicipalities = await getSuggestedMunicipality(incompleteName);
                setState((){});
              },
              onTextChosen: (name){
                setState((){
                  selectedMunicipality = name;
                  debugPrint("Selected municipality: $selectedMunicipality");
                  setState((){
                    widget.streetTextController.clear();
                  });
                });
              },
            ),
            AutocompleteList(
              labelText: "Rue *",
              hintText: "Rue",
              suggestions: suggestedStreets,
              textController: widget.streetTextController,
              onChangedCallback: (incompleteName)async{
                suggestedStreets = await getSuggestedStreet(incompleteName);
                setState((){});
              },
              onTextChosen: (name){
                setState((){
                  selectedStreet = name;
                  debugPrint("Selected street: $selectedStreet");
                });
              },
            ),
            TextFormField(
              controller: widget.streetNumberTextController,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: const InputDecoration(
                icon: Icon(Icons.location_city),
                hintText: 'Numéro civique',
                labelText: 'Numéro civique *',
              ),
              validator: (String? value) {
                return (value != null && !value.contains(RegExp(r'\d'))) ? 'Rentrez au moins une chiffre' : null;
              },
            ),
          ]
    );
  }
}

class NameSuggestion{
  String name;
  double similarityScore = 0;

  NameSuggestion(this.name, this.similarityScore);
}

class AutocompleteList extends StatefulWidget{
  static const double suggestionsHeight = 50;
  static const double maxHeightSuggestionsList = suggestionsHeight * 3;
  final ValueChanged? onChangedCallback;
  final ValueChanged? onTextChosen;
  final List<String> suggestions;
  final String hintText;
  final String labelText;
  final TextEditingController? textController;

  // constructor
  const AutocompleteList(
    {
      this.onChangedCallback,
      this.onTextChosen,
      Key? key,
      this.suggestions = const [],
      this.hintText = "",
      this.labelText = "",
      this.textController,
    }
  ) : super(key: key);


  @override
  State<AutocompleteList> createState() => AutocompleteListState();
}

class AutocompleteListState extends State<AutocompleteList>{
  late TextEditingController textController;
  bool showSuggestions = false;
  bool _hasFocus = false, _suggestionSelected = false;

  @override
  void initState() {
    // TODO: implement initState
    if (widget.textController == null){
      textController = TextEditingController();
    }else{
      textController = widget.textController!;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context){
    List<String> suggestions = widget.suggestions;
    if( !_hasFocus ||
        suggestions.isEmpty ||
        _suggestionSelected ||
        ((suggestions.length==1)&&(suggestions.first == textController.text))||
        textController.text.isEmpty){
      showSuggestions = false;
    }else{
      showSuggestions = true;
    }
    return Column(
      children: [
        Focus(
          child: TextField(
            autocorrect: false,
            enableSuggestions: false,
            controller: textController,
            decoration: InputDecoration(
              icon: const Icon(Icons.location_city),
              hintText: widget.hintText,
              labelText: widget.labelText,
            ),
            onChanged: (value) {
                if (widget.onChangedCallback != null){
                  widget.onChangedCallback!(value);
                }
                setState(() {
                  _suggestionSelected = false;
                });
            },
            onSubmitted: (submittedString){
              textController.text = widget.suggestions.first;
              if (widget.onTextChosen != null){
                widget.onTextChosen!(widget.suggestions.first);
              }
              setState(() {
                _suggestionSelected = true;
              });
            },
          ),
          onFocusChange: (hasFocus){
            setState((){
              _hasFocus = hasFocus;
            });
          },
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: showSuggestions?
            min(AutocompleteList.maxHeightSuggestionsList,
                widget.suggestions.length * AutocompleteList.suggestionsHeight)
            :0,
          child: Material(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemExtent: AutocompleteList.suggestionsHeight,
                itemCount: widget.suggestions.length,
                itemBuilder: (context, index){
                  return ListTile(
                    onTap: () {
                      setState(() {
                        textController.value = TextEditingValue(
                            text: widget.suggestions[index]
                        );
                        textController.selection = TextSelection.fromPosition(
                            TextPosition(offset: widget.suggestions[index].length)
                        );
                        if (widget.onTextChosen != null){
                          widget.onTextChosen!(widget.suggestions[index]);
                        }
                        _suggestionSelected = true;
                      });
                    },
                    leading: const CircleAvatar(
                      child: Icon(
                        Icons.pin_drop,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(widget.suggestions[index]),
                  );
                },
              )
          )
        )
      ]
    );
  }
}



















