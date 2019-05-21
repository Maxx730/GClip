bool debug_mode = false;

[GtkTemplate (ui = "/org/gnome/vala-starter/main-window.ui")]
public class Starter.MainWindow : Gtk.ApplicationWindow {
	//Grab our child elements from the UI
	[GtkChild]
	private Gtk.Button TestNotification;
	[GtkChild]
	private Gtk.Dialog ClearDialog;
	[GtkChild]
	private Gtk.Button ClearButton;
	[GtkChild]
	private Gtk.Button ConfirmClear;
	[GtkChild]
	private Gtk.Button CancelClear;
	[GtkChild]
	private Gtk.Button SettingsButton;
	[GtkChild]
	private Gtk.Popover SettingsPopover;
	[GtkChild]
	private Gtk.Button CancelSave;
	[GtkChild]
	private Gtk.FileChooserDialog SaveBackupDialog;
	[GtkChild]
	private Gtk.ImageMenuItem AboutApplication;
    [GtkChild]
    private Gtk.Dialog AboutDialog;
    [GtkChild]
    private Gtk.Button CloseAboutDialog;

	//Create out application service classes.
	private NotificationService notification;
	private ClipboardService clipboard;
	private PreferenceService preferences;
	private DataService database;

	//Keep a global array of clips.
	private Clip[] clips;

	public MainWindow(){
		if(debug_mode){
			print("INITIALIZED MAIN WINDOW\n");
		}

		clipboard = new ClipboardService();
		notification = new NotificationService();
		preferences = new PreferenceService();
		database = new DataService();

		//Set our signal callbacks before everything else.
		database.callback_event.connect((val) => {
			notification.CreateNotification("Database Created","GClipboard databased created!");
			//Next we are going to want to set the initial-run preference to true,
			//since the database has now been created.
			preferences.SetBoolPref("initial-run",true);
			InitializeUI();
		});

		//Callback when the user has copied something to the clipboard.
		database.insert_callback.connect((value) => {
			notification.CreateNotification("Clip Saved","'"+value+"' has been saved to history.");
		});

		//Check if this is the first time running the application, if so
		//we are going to want to create the SQLite database to store the clip data.
		if(!preferences.CheckBoolPref("initial-run")) {
			//Alert the user that the database is going to be created.
			database.CreateDatabase();
		} else {
			InitializeUI();
		}
	}

	//After we have made sure the database has been created etc,
	//we want to initialize the user interface for using the application.
	public void InitializeUI(){
		if(debug_mode){
			print("INITIALIZING APPLICATION UI\n");
		}

		//Test callback for testing the clip saved notification.
		TestNotification.clicked.connect(() => {
			database.InsertClip("TESTING");
		});

		SettingsButton.clicked.connect(() => {
			SettingsPopover.set_visible(true);
		});

		//Dialog to make sure the user would like the clear their clip
		//data, uses a dialog.
		ClearButton.clicked.connect(() => {
			ClearDialog.set_visible(true);
		});

		//Confirm and cancel buttons for the clear dialog.
		CancelClear.clicked.connect(() => {
			ClearDialog.set_visible(false);
		});

		ConfirmClear.clicked.connect(() => {
            ClearDialog.set_visible(false);
		});

		CancelSave.clicked.connect(() => {
			SaveBackupDialog.set_visible(false);
		});

		AboutApplication.activate.connect(() => {
			AboutDialog.set_visible(true);
		});

		CloseAboutDialog.clicked.connect(() => {
			AboutDialog.set_visible(false);
		});
	}

	//Class that handles displaying notifications
	//when something is copied etc.
	public class NotificationService {
		private GLib.Notification notif;

	    public NotificationService() {
	    	if(debug_mode){
	    		print("INITIALIZED NOTIFICATION SERVICE\n");
	    	}
	    }

	    //Sends a sample notification for testing purposes.
	    public void SampleNotification(){
	        notif = new GLib.Notification("Sample Notification");
	        notif.set_body("This is a sample notification!");
	        GLib.Application.get_default().send_notification(null,notif);
	    }

	    //Creates a new notification with a given title,icon and description.
	    public void CreateNotification(string title,string description) {
	        notif = new GLib.Notification(title);
	        notif.set_body(description);
	        GLib.Application.get_default().send_notification(null,notif);
	    }
	}

	//Class that handles listening to the clipboard.
	public class ClipboardService {
		private Gtk.Clipboard clipboard;
		private string last = null;

		public ClipboardService() {
			if(debug_mode){
				print("INITIALIZED CLIPBOARD SERVICE\n");
			}

	        clipboard = Gtk.Clipboard.get_for_display(Gdk.Display.get_default(),Gdk.SELECTION_CLIPBOARD);
	        clipboard.owner_change.connect((e) => {
	        	NotificationService notif = new NotificationService();
	        	DataService database = new DataService();

				string value = clipboard.wait_for_text().replace("'","\'");

				//Make sure the changed value is not equal to an empty string and
				//that it is not equal to the last copied item.
				if(value != null && value != last){
					notif.CreateNotification("Clip Added","'"+value+"' added to clip list.");
					database.InsertClip(value);
					last = value;
				}
	        });
		}
	}

	//Class that handles writing and reading data from the SQLite database.
	public class DataService {
		private Sqlite.Database database = null;
		private string errmsg;
		private Clip[] clips;

		//Signals are created here.
		public signal void callback_event(bool value);
		public signal void insert_callback(string value);
		public signal void get_callback(Clip[] clips);

		public DataService() {
		    if(debug_mode){
		    	print("INITIALIZED DATA SERVICE\n");
		    }

			int ec = Sqlite.Database.open("gclipboard-database.db",out database);

		    if(ec != Sqlite.OK) {
				print("ERROR OPENING DATABASE\n");
			}
		}

		//Method that creates the actual table in the database,
		//should only be run once when the application is first openend.
		public void CreateDatabase(){
			if(database != null){
				string query = "CREATE TABLE clips (
				        id INTEGER PRIMARY KEY NOT NULL,
				        value TEXT NOT NULL,
				        date TEXT NOT NULL
				    )";

				var ec = database.exec ( query,null,out errmsg );

				if ( ec != Sqlite.OK ) {
				        print ( "ERROR CREATING DATABASE\n" );
				} else {
				    if(debug_mode){
				    	print( "CREATED TABLE SUCCESSFULLY\n" );
				    }

				    callback_event(true);
				}
			}
		}

		public void InsertClip(string value){
				if ( database != null ) {
				    string query = "INSERT INTO clips (value,date) VALUES('" + value + "',DATETIME('now')) ";

				var ec = database.exec( query,null,out errmsg );

				if ( ec != Sqlite.OK ) {
				    print( "ERROR ADDING CLIP TO TABLE\n" );
				    print( errmsg + "\n" );
				} else {
				    if(debug_mode){
						print( "SUCCESS ADDING CLIP\n" );
					}

					insert_callback(value);
				}
			}
		}

		//Clears all the clips from the database.
		public void ClearClips(){
			if(database != null){
				if(debug_mode){
					print("CLEARING DATA FROM CLIP DATABASE\n");
				}

				string query = "";

			}
		}

		//Method that queries the database for all the saved clips.
		public void GetClips(){
			if(database != null){
				if(debug_mode){
					print("PULLING CLIPS FROM DATABASE\n");
				}

				Sqlite.Statement stmt;
				clips = {};
				string query = "SELECT * FROM clips";
				var ec = database.prepare_v2(query,query.length,out stmt);

				//Make sure there are no errors before building the new array of clips.
				if(ec != Sqlite.OK){
					print("ERROR RETRIEVING CLIPS FROM DATABASE");
				}else{
					while(stmt.step() == Sqlite.ROW){
						Clip clip = new Clip();
						for(int i = 0;i < stmt.column_count();i++){
							if(stmt.column_name(i) == "name"){
								clip.set_name(stmt.column_value(i).to_text());
							}

							if(stmt.column_name(i) == "date"){
								clip.set_date(stmt.)
							}
						}
					}
				}
			}
		}
	}

	//Class that handles saving and reading preferences.
	public class PreferenceService {
		private GLib.Settings settings;

		public PreferenceService() {
			if(debug_mode){
				print("INITIALIZED PREFERENCES SERVICE\n");
			}

			settings = new GLib.Settings("com.github.maxx730.gclipboard");
	    }

	    //Returns the value of a boolean preference;
	    public bool CheckBoolPref(string name) {
	        return settings.get_boolean(name);
	    }

	    public void SetBoolPref(string name,bool value) {
	        settings.set_boolean(name,value);
	    }
	}

	//Class that represents the clip object that is pulled and saved
	//from the SQLite database.
	public class Clip{
		private int id;
		private string value;
		private string date;

		public void set_id(int id){
			this.id = id;
		}

		public void set_value(string value){
			this.value = value;
		}

		public void set_date(string date){
			this.date = date;
		}

		public int get_id(){
			return this.id;
		}

		public string get_value(){
			return this.value;
		}

		public string get_date(){
			return this.date;
		}
	}
}
