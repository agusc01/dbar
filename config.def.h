#define SC(ruta) "$HOME/.config/dbar/scripts/" #ruta

//Modify this file to change what commands output to your statusbar, and recompile using the make command.
static const Bar dbar[] = {
    // TODO: use Update Signal
    //Icon  Command Update     Interval   Update Signal
    {"",    SC("brightness"),    10,             0  },
    {"",    SC("volume"),        10,             0  },
    {"",    SC("thermal"),       10,             0  },
    {"",    SC("cpu"),            5,             0  },
    {"",    SC("memory"),         5,             0  },
    {"",    SC("date"),          50,             0  },
    {"",    SC("wifi"),          60,             0  },
    {"",    SC("battery"),       60,             0  },
};

//sets delimeter between status commands. NULL character ('\0') means no delimeter.
static char delim[] = "  ";
static unsigned int delimLen = 2;
