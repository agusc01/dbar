#define SC(ruta) "$HOME/.config/dbar/scripts/" #ruta

//Modify this file to change what commands output to your statusbar, and recompile using the make command.
static const Block blocks[] = {
    //Icon  Command Update     Interval   Update Signal
    {"",    SC("brightness.sh"),         0,            10  },
    {"",    SC("volume.sh"),         0,            10  },
    {"",    SC("thermal.sh"),            3,             0  },
    {"",    SC("cpu.sh"),            3,             0  },
    {"",    SC("memory.sh"),        10,             0  },
    {"",    SC("wifi.sh"),          60,             0  },
    {"",    SC("date.sh"),          50,             0  },
    {"",    SC("battery.sh"),       60,             0  },
};

//sets delimeter between status commands. NULL character ('\0') means no delimeter.
static char delim[] = " | ";
static unsigned int delimLen = 3;
