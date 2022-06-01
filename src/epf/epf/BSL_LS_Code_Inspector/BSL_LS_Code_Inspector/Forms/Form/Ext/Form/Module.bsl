&AtClient
Function CheckBSLSever()
	FileOfAnalyzer = New File(Object.BSL_LanguageServerForder + "\bsl-language-server.exe");
	If Not FileOfAnalyzer.Exists() Then
		Message(NStr("en = 'Setup BSL LS from git and try again'; ru = 'Установите BSL LS из гита и попробуйте еще раз'"));
		Return False;
	EndIf;
	
	Return True;
EndFunction

&AtServer
Procedure DiagnosticsCollection(StreamJSON, DataTree)
	ValueTypesOfJSON = New Array();
	ValueTypesOfJSON.Add(JSONValueType.Number);
	ValueTypesOfJSON.Add(JSONValueType.String);
	ValueTypesOfJSON.Add(JSONValueType.Boolean);
	ValueTypesOfJSON.Add(JSONValueType.Null);
	
	JSONValueTypeObjectStart = JSONValueType.ObjectStart;
	JSONValueTypePropertyName = JSONValueType.PropertyName;
	JSONValueTypeArrayStart = JSONValueType.ArrayStart;
	PropertyName = Undefined;
	
	While StreamJSON.Read() Do
		TypeOfJSON = StreamJSON.CurrentValueType;
		If TypeOfJSON = JSONValueTypeObjectStart OR TypeOfJSON = JSONValueTypeArrayStart Then
			NewObject = ?(TypeOfJSON = JSONValueTypeObjectStart, New Map, New Array);
			If TypeOf(DataTree) = Type("Array") Then
				DataTree.Add(NewObject);
			ElsIf TypeOf(DataTree) = Type("Map") And ValueIsFilled(PropertyName) Then
				DataTree.Insert(PropertyName, NewObject);
			EndIf;
			DiagnosticsCollection(StreamJSON, NewObject);
			If DataTree = Undefined Then
				DataTree = NewObject;
			EndIf;
		ElsIf TypeOfJSON = JSONValueTypePropertyName Then
			PropertyName = StreamJSON.CurrentValue;
		ElsIf ValueTypesOfJSON.Find(TypeOfJSON) <> Undefined Then
			If TypeOf(DataTree) = Type("Array") Then
				DataTree.Add(StreamJSON.CurrentValue);
			ElsIf TypeOf(DataTree) = Type("Map") Then
				DataTree.Вставить(PropertyName, StreamJSON.CurrentValue);
			EndIf;
		Else
			Return;
		EndIf;
	EndDo;
EndProcedure

&AtServer
Procedure ReportFileProcessing(Address)
	Data = GetFromTempStorage(Address);
	
	ReportFileName = TempFilesDir() + "temp.xml";
	
	Data.Write(ReportFileName);
	
	JSONReader = New JSONReader;
	JSONReader.OpenFile(ReportFileName);
	CheckResults = Undefined;
	DiagnosticsCollection(JSONReader, CheckResults);
	JSONReader.Close();
	
	GetResultAtServer(CheckResults.Get("fileinfos"));
EndProcedure

&AtClient
Procedure Check(Command)
	If Not CheckBSLSever() Then
		Return;
	EndIf;
	
	FileName = Object.BSL_LanguageServerForder + "\tmp\module.bsl";
	FileForAnalisis = New TextDocument();
	FileForAnalisis.SetText(TrimAll(Object.Code));
	FileForAnalisis.Write(FileName);
	
	PathInjection = "";
	If Object.CheckOptions = "Custom" Then
		TempFile = Object.BSL_LanguageServerForder + "\tmp\check_options.json";
		SaveOptionsToFile(TempFile);
		PathInjection = " -c " + TempFile;
	EndIf;
	If Object.CheckMode = "Code" Then
		Path = Object.BSL_LanguageServerForder + "\bsl-language-server.exe -a -q " + PathInjection + " -s " + Object.BSL_LanguageServerForder + "\tmp --reporter=json -o " + Object.BSL_LanguageServerForder + "\tmp";
	Else
	    Path = Object.BSL_LanguageServerForder + "\bsl-language-server.exe -a -q " + PathInjection + " -s " + Object.UnloadedConfigurationFolder + " --reporter=json -o " + Object.BSL_LanguageServerForder + "\tmp";
	EndIf;
	
	BATFileName = Left(Object.BSL_LanguageServerForder, 2) + "\check.bat";
	BAT = New TextDocument();
	BAT.SetText(Left(Object.BSL_LanguageServerForder, 2) + Chars.LF + Path);
	BAT.Write(BATFileName);
	ReportFileName = Object.BSL_LanguageServerForder + "\tmp\bsl-json.json";
	
	ReportFile = New File(ReportFileName);
	If ReportFile.Exists() Then
		DeleteFiles(ReportFileName);
	EndIf;
	
	System(BATFileName, Left(Object.BSL_LanguageServerForder, 2));
		
	If Not ReportFile.Exists() Then
		Message(NStr("en = 'Result file does not exist! Analisis of test was not completed successfully.'; ru = 'Файл результатов анализа не существует. Анализ не был завершен успешно.'"));
		
		Return;
	EndIf;
	
	Handler = New NotifyDescription("CheckEnd", ThisObject);
	BeginPutFileToServer(Handler, , , "", ReportFile.FullName, UUID);
	
	DeleteFiles(BATFileName);
	
	Items.Results.Visible = True;
EndProcedure

&AtClient
Procedure CheckEnd(FileDescription, AdditionalParameters) Export
	ReportFileProcessing(FileDescription.Address);
EndProcedure

&AtServer
Procedure GetResultAtServer(Diagnostics)
	CheckResult.Clear();
	CheckResult.StartRowAutoGrouping();
	
	ProcessorObject = FormAttributeToValue("Object");
	Template = ProcessorObject.GetTemplate("CheckResult");
	AreaNoErrors = Template.GetArea("NoErrors");
	
	If Diagnostics.Count() = 0 Then
		CheckResult.Put(AreaNoErrors);
		
		Return;
	EndIf;

	AreaTitle = Template.GetArea("Title");
	AreaRow = Template.GetArea("Row");
	AreaBugs = Template.GetArea("Bugs");
	AreaWarnings = Template.GetArea("Warnings");
	AreaInformation = Template.GetArea("Information");
	EmptyRow = Template.GetArea("EmptyRow");
	AreaModule = Template.GetArea("Module");
	
	NeedToPutAreaModule = Diagnostics.Count() > 1;
	BugsCount = 0;
	WarningsCount = 0;
	InformationsCount = 0;
	
	CheckResult.Put(AreaTitle);
	
	For Each Diagnostic In Diagnostics Do
		Bugs = New Array;
		Warnings = New Array;
		Informations = New Array;
		Level = 1;
		
		If NeedToPutAreaModule Then
			CheckResult.Put(EmptyRow, Level);
			AreaModule.Parameters.Module = Diagnostic.Get("path");
			CheckResult.Put(AreaModule, Level);
			Level = Level + 1;
		EndIf;
		
		For Each Details In Diagnostic.Get("diagnostics") Do
			ProblemStructure = New Structure;
			ProblemStructure.Insert("Line", Details.Get("range").Get("start").Get("line") + 1);
			ProblemStructure.Insert("Description", Details.Get("message"));
			If Details.Get("severity") = "Error" Then
				Bugs.Add(ProblemStructure);
			ElsIf Details.Get("severity") = "Warning" Then
				Warnings.Add(ProblemStructure);
			Else
				Informations.Add(ProblemStructure);
			EndIf;
		EndDo;
		
		If Bugs.Count() > 0 Then
			CheckResult.Put(AreaBugs, Level);
			For Each Bug In Bugs Do
				AreaRow.Parameters.Line = Bug.Line;
				AreaRow.Parameters.Description = Bug.Description;
				CheckResult.Put(AreaRow, Level + 1);
			EndDo;
			BugsCount = BugsCount + Bugs.Count();
		EndIf;
		If Warnings.Count() > 0 Then
			CheckResult.Put(EmptyRow, Level);
			CheckResult.Put(AreaWarnings, Level);
			For Each Warning In Warnings Do
				AreaRow.Parameters.Line = Warning.Line;
				AreaRow.Parameters.Description = Warning.Description;
				CheckResult.Put(AreaRow, Level + 1);
			EndDo;
			WarningsCount = WarningsCount + Warnings.Count();
		EndIf;
		If Informations.Count() > 0 Then
			CheckResult.Put(EmptyRow, Level);
			CheckResult.Put(AreaInformation, Level);
			For Each Information In Informations Do
				AreaRow.Parameters.Line = Information.Line;
				AreaRow.Parameters.Description = Information.Description;
				CheckResult.Put(AreaRow, Level + 1);
			EndDo;
			InformationsCount = InformationsCount + Informations.Count();
		EndIf;
	EndDo;
	
	CheckResult.EndRowAutoGrouping();
	
	SummaryResult.Clear();
	Template = ProcessorObject.GetTemplate("Summary");
	AreaSummary = Template.GetArea("Summary");
	AreaSummary.Parameters.Bugs = BugsCount;
	AreaSummary.Parameters.Warnings = WarningsCount;
	AreaSummary.Parameters.Information = InformationsCount;
	SummaryResult.Put(AreaSummary);
EndProcedure

&AtClient
Procedure CodeOnChange(Item)
	Items.Results.Visible = False;
EndProcedure

&AtClient
Procedure CheckModeOnChange(Item)
	Items.Results.Visible = False;
	Items.Code.Visible = Object.CheckMode = "Code";
	Items.UnloadedConfigurationFolder.Visible = Object.CheckMode = "Folder";
EndProcedure

&AtClient
Procedure BSL_LanguageServerForderStartChoice(Item, ChoiceData, StandardProcessing)
	SelectMode = FileDialogMode.ChooseDirectory;
	SelectionDialog = New FileDialog(SelectMode);
	SelectionDialog.Directory = "";
	SelectionDialog.Multiselect = False;
	SelectionDialog.Title = NStr("en = 'Select folder of BSL LS'; ru = 'Выберите папку с BSL LS'");
	
	If SelectionDialog.Choose() Then
		Object.BSL_LanguageServerForder = SelectionDialog.Directory;
	EndIf;
EndProcedure

&AtClient
Procedure UnloadedConfigurationFolderStartChoice(Item, ChoiceData, StandardProcessing)
	SelectMode = FileDialogMode.ChooseDirectory;
	SelectionDialog = New FileDialog(SelectMode);
	SelectionDialog.Directory = "";
	SelectionDialog.Multiselect = False;
	SelectionDialog.Title = NStr("en = 'Select folder of dump of configuration'; ru = 'Укажите папку выгрузки конфигурации'");
	
	If SelectionDialog.Choose() Then
		Object.UnloadedConfigurationFolder = SelectionDialog.Directory;
	EndIf;
EndProcedure

&AtClient
Procedure SaveOptionsToFile(File)
	FileSctucture = New Structure;
	FileSctucture.Insert("language", "en");
	
	DiagnosticsParameters = New Structure;
	DiagnosticsParameters.Insert("AllFunctionPathMustHaveReturn", AllFunctionPathMustHaveReturn);
	DiagnosticsParameters.Insert("AssignAliasFieldsInQuery", AssignAliasFieldsInQuery);
	DiagnosticsParameters.Insert("BeginTransactionBeforeTryCatch", BeginTransactionBeforeTryCatch);
	DiagnosticsParameters.Insert("CachedPublic", CachedPublic);
	DiagnosticsParameters.Insert("CanonicalSpellingKeywords", CanonicalSpellingKeywords);
	DiagnosticsParameters.Insert("CodeAfterAsyncCall", CodeAfterAsyncCall);
	DiagnosticsParameters.Insert("CodeBlockBeforeSub", CodeBlockBeforeSub);
	DiagnosticsParameters.Insert("CodeOutOfRegion", CodeOutOfRegion);
	DiagnosticsParameters.Insert("CognitiveComplexity", CognitiveComplexity);
	DiagnosticsParameters.Insert("CommandModuleExportMethods", CommandModuleExportMethods);
	DiagnosticsParameters.Insert("CommentedCode", CommentedCode);
	DiagnosticsParameters.Insert("CommitTransactionOutsideTryCatch", CommitTransactionOutsideTryCatch);
	DiagnosticsParameters.Insert("CommonModuleAssign", CommonModuleAssign);
	DiagnosticsParameters.Insert("CommonModuleInvalidType", CommonModuleInvalidType);
	DiagnosticsParameters.Insert("CommonModuleMissingAPI", CommonModuleMissingAPI);
	DiagnosticsParameters.Insert("CommonModuleNameCached", CommonModuleNameCached);
	DiagnosticsParameters.Insert("CompilationDirectiveLost", CompilationDirectiveLost);
	DiagnosticsParameters.Insert("CompilationDirectiveNeedLess", CompilationDirectiveNeedLess);
	DiagnosticsParameters.Insert("CreateQueryInCycle", CreateQueryInCycle);
	DiagnosticsParameters.Insert("CyclomaticComplexity", CyclomaticComplexity);
	DiagnosticsParameters.Insert("DataExchangeLoading", DataExchangeLoading);
	DiagnosticsParameters.Insert("DeprecatedAttributes8312", DeprecatedAttributes8312);
	DiagnosticsParameters.Insert("DeprecatedCurrentDate", DeprecatedCurrentDate);
	DiagnosticsParameters.Insert("DeprecatedFind", DeprecatedFind);
	DiagnosticsParameters.Insert("DeprecatedMessage", DeprecatedMessage);
	DiagnosticsParameters.Insert("DeprecatedMethods8310", DeprecatedMethods8310);
	DiagnosticsParameters.Insert("DeprecatedMethods8317", DeprecatedMethods8317);
	DiagnosticsParameters.Insert("DeprecatedTypeManagedForm", DeprecatedTypeManagedForm);
	DiagnosticsParameters.Insert("EmptyCodeBlock", EmptyCodeBlock);
	DiagnosticsParameters.Insert("ExecuteExternalCode", ExecuteExternalCode);
	DiagnosticsParameters.Insert("ExecuteExternalCodeInCommonModule", ExecuteExternalCodeInCommonModule);
	DiagnosticsParameters.Insert("FormDataToValue", FormDataToValue);
	DiagnosticsParameters.Insert("GetFormMethod", GetFormMethod);
	DiagnosticsParameters.Insert("IfElseIfEndsWithElse", IfElseIfEndsWithElse);
	DiagnosticsParameters.Insert("IsInRoleMethod", IsInRoleMethod);
	DiagnosticsParameters.Insert("MissingSpace", MissingSpace);
	DiagnosticsParameters.Insert("MultilingualStringHasAllDeclaredLanguages", MultilingualStringHasAllDeclaredLanguages);
	DiagnosticsParameters.Insert("MultilingualStringUsingWithTemplate", MultilingualStringUsingWithTemplate);
	DiagnosticsParameters.Insert("NestedStatements", NestedStatements);
	DiagnosticsParameters.Insert("OSUsersMethod", OSUsersMethod);
	DiagnosticsParameters.Insert("SetPermissionsForNewObjects", SetPermissionsForNewObjects);
	DiagnosticsParameters.Insert("SpaceAtStartComment", SpaceAtStartComment);
	DiagnosticsParameters.Insert("TempFilesDir", TempFilesDir);
	DiagnosticsParameters.Insert("TmpAdress", TmpAdress);
	DiagnosticsParameters.Insert("Typo", Typo);
	DiagnosticsParameters.Insert("UnaryPlusInConcatenation", UnaryPlusInConcatenation);
	DiagnosticsParameters.Insert("UnionAll", UnionAll);
	DiagnosticsParameters.Insert("UnsafeSafeModeMethodCall", UnsafeSafeModeMethodCall);
	DiagnosticsParameters.Insert("UsingExternalCodeTools", UsingExternalCodeTools);
	DiagnosticsParameters.Insert("UsingFindElementByString", UsingFindElementByString);
	DiagnosticsParameters.Insert("UsingGoto", UsingGoto);
	DiagnosticsParameters.Insert("UsingHardcodeNetworkAddress", UsingHardcodeNetworkAddress);
	DiagnosticsParameters.Insert("UsingHardcodeSecretInformation", UsingHardcodeSecretInformation);
	DiagnosticsParameters.Insert("UsingLikeInQuery", UsingLikeInQuery);
	DiagnosticsParameters.Insert("UsingObjectNotAvailableUnix", UsingObjectNotAvailableUnix);
	DiagnosticsParameters.Insert("UsingSynchronousCalls", UsingSynchronousCalls);
	DiagnosticsParameters.Insert("UsingThisForm", UsingThisForm);
	DiagnosticsParameters.Insert("YoLetterUsage", YoLetterUsage);
	                                                                                           
	Diagnostics = New Structure;
	Diagnostics.Insert("parameters", DiagnosticsParameters);
	FileSctucture.Insert("diagnostics", Diagnostics);
	
	JSONWriter = New JSONWriter;
	JSONWriter.OpenFile(File,,, New JSONWriterSettings(, Chars.Tab));
	WriteJSON(JSONWriter, FileSctucture);
	JSONWriter.Close();
EndProcedure

&AtClient
Procedure SaveCheckDiaglosticsToFile(Command)
	SelectMode = FileDialogMode.Save;
	SelectionDialog = New FileDialog(SelectMode);
	SelectionDialog.Directory = Object.BSL_LanguageServerForder;
	SelectionDialog.Multiselect = False;
	SelectionDialog.Filter = "BSL LS configuration (*.json) | *.json";
	
	If SelectionDialog.Choose() Then
		SaveOptionsToFile(SelectionDialog.FullFileName);
	EndIf;
EndProcedure

&AtClient
Procedure LoadCheckDiaglosticsFromFile(Command)
	SelectMode = FileDialogMode.Open;
	SelectionDialog = New FileDialog(SelectMode);
	SelectionDialog.Directory = Object.BSL_LanguageServerForder;
	SelectionDialog.Multiselect = False;
	SelectionDialog.Filter = "BSL LS configuration (*.json) | *.json";
	SelectionDialog.Title = NStr("en = 'Select BSL LS configuration file'; ru = 'Укажите файл конфигурации BSL LS'");
	
	If SelectionDialog.Choose() Then
		ConfigurationFile = SelectionDialog.FullFileName;
		JSONReader = New JSONReader;
		JSONReader.OpenFile(ConfigurationFile);
		CheckDataParameters = ReadJSON(JSONReader);
		ParametersStructure = CheckDataParameters.diagnostics.parameters;
		JSONReader.Close();
		
		AllFunctionPathMustHaveReturn = ParametersStructure.AllFunctionPathMustHaveReturn;
		AssignAliasFieldsInQuery = ParametersStructure.AssignAliasFieldsInQuery;
		BeginTransactionBeforeTryCatch = ParametersStructure.BeginTransactionBeforeTryCatch;
		CachedPublic = ParametersStructure.CachedPublic;
		CanonicalSpellingKeywords = ParametersStructure.CanonicalSpellingKeywords;
		CodeAfterAsyncCall = ParametersStructure.CodeAfterAsyncCall;
		CodeBlockBeforeSub = ParametersStructure.CodeBlockBeforeSub;
		CodeOutOfRegion = ParametersStructure.CodeOutOfRegion;
		CognitiveComplexity = ParametersStructure.CognitiveComplexity;
		CommandModuleExportMethods = ParametersStructure.CommandModuleExportMethods;
		CommentedCode = ParametersStructure.CommentedCode;
		CommitTransactionOutsideTryCatch = ParametersStructure.CommitTransactionOutsideTryCatch;
		CommonModuleAssign = ParametersStructure.CommonModuleAssign;
		CommonModuleInvalidType = ParametersStructure.CommonModuleInvalidType;
		CommonModuleMissingAPI = ParametersStructure.CommonModuleMissingAPI;
		CommonModuleNameCached = ParametersStructure.CommonModuleNameCached;
		CompilationDirectiveLost = ParametersStructure.CompilationDirectiveLost;
		CompilationDirectiveNeedLess = ParametersStructure.CompilationDirectiveNeedLess;
		CreateQueryInCycle = ParametersStructure.CreateQueryInCycle;
		CyclomaticComplexity = ParametersStructure.CyclomaticComplexity;
		DataExchangeLoading = ParametersStructure.DataExchangeLoading;
		DeprecatedAttributes8312 = ParametersStructure.DeprecatedAttributes8312;
		DeprecatedCurrentDate = ParametersStructure.DeprecatedCurrentDate;
		DeprecatedFind = ParametersStructure.DeprecatedFind;
		DeprecatedMessage = ParametersStructure.DeprecatedMessage;
		DeprecatedMethods8310 = ParametersStructure.DeprecatedMethods8310;
		DeprecatedMethods8317 = ParametersStructure.DeprecatedMethods8317;
		DeprecatedTypeManagedForm = ParametersStructure.DeprecatedTypeManagedForm;
		EmptyCodeBlock = ParametersStructure.EmptyCodeBlock;
		ExecuteExternalCode = ParametersStructure.ExecuteExternalCode;
		ExecuteExternalCodeInCommonModule = ParametersStructure.ExecuteExternalCodeInCommonModule;
		FormDataToValue = ParametersStructure.FormDataToValue;
		GetFormMethod = ParametersStructure.GetFormMethod;
		IfElseIfEndsWithElse = ParametersStructure.IfElseIfEndsWithElse;
		IsInRoleMethod = ParametersStructure.IsInRoleMethod;
		MissingSpace = ParametersStructure.MissingSpace;
		MultilingualStringHasAllDeclaredLanguages = ParametersStructure.MultilingualStringHasAllDeclaredLanguages;
		MultilingualStringUsingWithTemplate = ParametersStructure.MultilingualStringUsingWithTemplate;
		NestedStatements = ParametersStructure.NestedStatements;
		OSUsersMethod = ParametersStructure.OSUsersMethod;
		SetPermissionsForNewObjects = ParametersStructure.SetPermissionsForNewObjects;
		SpaceAtStartComment = ParametersStructure.SpaceAtStartComment;
		TempFilesDir = ParametersStructure.TempFilesDir;
		TmpAdress = ParametersStructure.TmpAdress;
		Typo = ParametersStructure.Typo;
		UnaryPlusInConcatenation = ParametersStructure.UnaryPlusInConcatenation;
		UnionAll = ParametersStructure.UnionAll;
		UnsafeSafeModeMethodCall = ParametersStructure.UnsafeSafeModeMethodCall;
		UsingExternalCodeTools = ParametersStructure.UsingExternalCodeTools;
		UsingFindElementByString = ParametersStructure.UsingFindElementByString;
		UsingGoto = ParametersStructure.UsingGoto;
		UsingHardcodeNetworkAddress = ParametersStructure.UsingHardcodeNetworkAddress;
		UsingHardcodeSecretInformation = ParametersStructure.UsingHardcodeSecretInformation;
		UsingLikeInQuery = ParametersStructure.UsingLikeInQuery;
		UsingObjectNotAvailableUnix = ParametersStructure.UsingObjectNotAvailableUnix;
		UsingSynchronousCalls = ParametersStructure.UsingSynchronousCalls;
		UsingThisForm = ParametersStructure.UsingThisForm;
		YoLetterUsage = ParametersStructure.YoLetterUsage;
	EndIf;
EndProcedure

&AtClient
Procedure CheckOptionsOnChange(Item)
	Items.CheckDiagnostics.Visible = Object.CheckOptions = "Custom";
EndProcedure
