section "Mach O" {

little_endian

section "Header" {
    set magic [uint32];
    move -4;
    uint32 -hex "Magic";

    uint32 -hex "cputype (CPU_TYPE_x86_64)";
    uint32 "cpusubtype (CPU_SUBTYPE_X86_64_ALL)";
    uint32 "filetype";

    set ncmds [uint32];
    move -4;
    uint32 "ncmds";

    uint32 "sizeofcmds";
    uint32 -hex "flags";

    if {$magic == 0xFEEDFACF} {
        uint32 "reserved";
    }
}


#Constants for the cmd field of all load commands, the type
set load_commands { 
    LC_SEGMENT 
    LC_SYMTAB
    LC_SYMSEG
    LC_THREAD
    LC_UNIXTHREAD
    LC_LOADFVMLIB
    LC_IDFVMLIB
    LC_IDENT
    LC_FVMFILE
    LC_PREPAGE
    LC_DYSYMTAB
    LC_LOAD_DYLIB
    LC_ID_DYLIB
    LC_LOAD_DYLINKER
    LC_ID_DYLINKER
    LC_PREBOUND_DYLIB

    LC_ROUTINES
    LC_SUB_FRAMEWORK
    LC_SUB_UMBRELLA
    LC_SUB_CLIENT
    LC_SUB_LIBRARY
    LC_SUB_TWOLEVEL_HINTS
    LC_PREBIND_CKSUM

    LC_LOAD_WEAK_DYLIB

    LC_SEGMENT_64
    
    LC_ROUTINES_64
    LC_UUID
    LC_RPATH
    LC_CODE_SIGNATURE
    LC_SEGMENT_SPLIT_INFO
    LC_REEXPORT_DYLIB
    LC_LAZY_LOAD_DYLIB
    LC_ENCRYPTION_INFO
    LC_DYLD_INFO
    LC_DYLD_INFO_ONLY
    LC_LOAD_UPWARD_DYLIB
    LC_VERSION_MIN_MACOSX
    LC_VERSION_MIN_IPHONEOS
    LC_FUNCTION_STARTS
    LC_DYLD_ENVIRONMENT
    LC_MAIN
    LC_DATA_IN_CODE
    LC_SOURCE_VERSION
    LC_DYLIB_CODE_SIGN_DRS
    LC_ENCRYPTION_INFO_64
    LC_LINKER_OPTION
    LC_LINKER_OPTIMIZATION_HINT
    LC_VERSION_MIN_TVOS
    LC_VERSION_MIN_WATCHOS
    LC_NOTE
    LC_BUILD_VERSION
}

set i 1;
set LC_REQ_DYLD 0x80000000
foreach load_command $load_commands {
    if {$load_command == "LC_REEXPORT_DYLIB"} {
        set $load_command [expr 0x1f | $LC_REQ_DYLD];
        incr i;
    } elseif {$load_command == "LC_DYLD_INFO_ONLY"} {
        set $load_command [expr 0x22 | $LC_REQ_DYLD];
    } elseif {$load_command == "LC_MAIN"} {
        set $load_command [expr 0x28 | $LC_REQ_DYLD];
        incr i;
    } else {
        set $load_command $i;
        incr i;
    }
}

proc load_command_common {} {
    uint32 -hex "cmd";
    set cmdsize [uint32]
    move -4
    uint32 "cmdsize";
    return $cmdsize
}

proc segment_command_64 {} {
    section "segment_command_64" {
        load_command_common
        ascii 16 "segname"
        uint64 -hex "vmaddr"
        uint64 "vmsize"
        uint64 -hex "fileoff"
        uint64 "filesize"
        int32 "maxprot"
        int32 "initprot"
        
        set nsects [uint32]
        move -4
        uint32 "nsects"

        uint32 -hex "flags"

        for {set j 0} {$j < $nsects} {incr j} {
            section "section_64" {
                set sectname [ascii 16]
                move -16

                ascii 16 "sectname";
                ascii 16 "segname";
                uint64 "addr";

                set size [uint64];
                move -8;
                uint64 "size";

                set offset [uint32];
                move -4;
                uint32 -hex "offset";

                uint32 "align";

                set reloff [uint32];
                move -4;
                uint32 -hex "reloff";
                set nreloc [uint32];
                move -4;
                uint32 "nreloc";
                uint32 "flags";
                uint32 -hex "reserved1"
                uint32 "reserved2";
                uint32 "reserved3";

                proc l$j {offset sectname size} {
                    set currentPos [pos];
                    goto $offset;
                    section $sectname {
                        if {$size > 0 && $size <= [expr [len] - $offset]} {
                            hex $size "body";
                        } else {
                            entry "body" "N/A"
                        }
                    }
                    goto $currentPos
                }
                l$j $offset $sectname $size

                if {$nreloc > 0} {
                    set currentPos [pos];
                    goto $reloff;
                    section {Relocation Info} {
                        for {set i 0} {$i < $nreloc} {incr i} {
                            section {Relocation entry} {
                                set r_address [int32];
                                move -4;
                                if {[expr $r_address & 0x80000000] == 0x0} {
                                    uint32 -hex "r_address";
                                    set startPos [pos];
                                    set field [uint32];
                                    set endPos [pos];
                                    set length [expr $endPos - $startPos]
                                    entry "r_symbolnum" [expr ($field & 0x00ffffff)] $length $startPos;
                                    entry "r_pcrel"     [expr ($field & 0x01000000) >> 24] $length $startPos;
                                    entry "r_length"    [expr ($field & 0x06000000) >> 25] $length $startPos;
                                    entry "r_extern"    [expr ($field & 0x08000000) >> 27] $length $startPos;
                                    entry "r_type"      [expr ($field & 0xf0000000) >> 28] $length $startPos;
                                } else {
                                    entry "Scattered relocation info parser not implemented."
                                }
                            }
                        }
                    }
                    goto $currentPos;
                }
            }
        }
    }

}

proc build_version_command {} {
    section "build_version_command" {
        load_command_common
        uint32 "platform"
        uint32 -hex "minos"
        uint32 "sdk"

        set ntools [uint32]
        move -4
        uint32 "ntools"

        for {set j 0} {$j < $ntools} {incr j} {
            section "build_tool_version" {
                uint32 "tool"
                uint32 "version"
            }
        }
    }
}

array set symtab {};
proc symtab_command {} {
    section "symtab_command" {
        load_command_common
        set symoff [uint32];
        move -4;
        uint32 -hex "symoff";

        set nsyms [uint32];
        move -4
        uint32 "nsyms";

        set stroff [uint32];
        move -4;
        uint32 -hex "stroff";

        set strsize [uint32];
        move -4;
        uint32 -hex "strsize";

        set currentpos [pos];
        goto $symoff;
        section "symtable" {
            for {set j 0} {$j < $nsyms} {incr j} {
                section "nlist_64" {
                    set n_strx [uint32]
                    move -4
                    uint32 -hex "n_strx";

                    uint8 -hex "n_type";
                    uint8 -hex "n_sect";
                    uint16 -hex "n_desc";
                    uint64 -hex "n_value";

                    set p1 [pos]
                    set symbol_offset [expr $stroff + $n_strx];
                    goto $symbol_offset 
                    set strlen 1;
                    set char [ascii 1];

                    #"" Represents the null character in Tcl
                    while {![string equal $char ""]} {
                        set char [ascii 1]
                        incr strlen;
                    }
                    goto $symbol_offset

                    set ::symtab($j) [ascii $strlen];
                    move -$strlen;
                    ascii $strlen "(symbol)"
                    goto $p1
                }
            }
            #hex [expr $stroff - $symoff + $strsize] body;
        }
        goto $currentpos;
    }
}

proc dysymtab_command {} {
    section "dysymtab_command" {
        load_command_common
        uint32 ilocalsym;
        uint32 nlocalsym;
        uint32 iextdefsym;
        uint32 nextdefsym;
        uint32 iundefsym;
        uint32 nundefsym;
        
        uint32 -hex tocoff;
        uint32 ntoc;
        
        uint32 -hex modtaboff;
        uint32 nmodtab;

        uint32 -hex extrefsymoff
        uint32 nextrefsyms;

        set indirectsymoff [uint32];
        move -4;
        uint32 -hex indirectsymoff
        set nindirectsyms [uint32];
        move -4;
        uint32 nindirectsyms;

        uint32 -hex extreloff
        uint32 nextrel

        uint32 -hex locreloff
        uint32 nlocrel

        if {$nindirectsyms > 0} {
            set currentPos [pos];
            goto $indirectsymoff;
            section "Indirect symbol table" {
                for {set i 0} {$i < $nindirectsyms} {incr i} {
                    section "Indirect symbol" {
                        set index [uint32]
                        move -4;
                        uint32 index;
                        if {$index < [array size ::symtab]} {
                            entry "(symbol)" $::symtab($index)
                        }
                    }
                }
            }
            goto $currentPos;
        }
    }
}

proc dyld_info_command {} {
    section "dyld_info_command" {
        load_command_common
        source ./mach-o/dyld_info
    }
}

proc dylinker_command {} {
    section "dylinker_command" {
        set cmdoffset [pos]
        set cmdsize [load_command_common]

        uint32 -hex "name";

        set currentpos [pos]

        ascii [expr $cmdsize - ($currentpos - $cmdoffset)] "(namestr)"

        #goto $nameoffset

    }
}

proc uuid_command {} {
    section "uuid_command" {
        load_command_common
        hex 16 "uuid";
    }
}

proc source_version_command {} {
    section "source_version_command" {
        load_command_common
        uint64 -hex "version"
    }
}

proc entry_point_command {} {
    section "entry_point_command" {
        load_command_common
        uint64 -hex "entryoff";
        uint64 -hex "stacksize";
    }
}

proc dylib_command {cmdstr} {
    section "dylib_command" {
        entry "(cmd_name)" $cmdstr
        set cmdoffset [pos]
        set cmdsize [load_command_common]
        uint32 "name";
        uint32 "timestamp";
        uint32 "current_version";
        uint32 "compatibility_version";

        set currentpos [pos]

        ascii [expr $cmdsize - ($currentpos - $cmdoffset)] "(namestr)"
    }
}

proc linkedit_data_command {cmdstr} {
    section "linkedit_data_command" {
        entry "(cmd_name)" $cmdstr
        load_command_common 
        set dataoff [uint32]
        move -4
        uint32 -hex "dataoff"

        set datasize [uint32]
        move -4
        uint32 "datasize"

        #if {$cmdstr == LC_DATA_IN_CODE} {
            
        #} else {
            set currentpos [pos]
            if {$datasize > 0} {
                goto $dataoff
                hex $datasize "data blob"
                goto $currentpos
            }
        #}
    }
}

section "Load Commands" {
    for {set i 0} {$i < $ncmds}  {incr i} {
        set cmd [uint32];
        set cmdsize [uint32];
        move -8;

        if {$cmd == $LC_SEGMENT_64} {
            segment_command_64
        } elseif {$cmd == $LC_BUILD_VERSION} {
            build_version_command
        } elseif {$cmd == $LC_SYMTAB} {
            symtab_command
        } elseif {$cmd == $LC_DYSYMTAB} {
            dysymtab_command
        } elseif {$cmd == $LC_DYLD_INFO_ONLY} {
            dyld_info_command
        } elseif {$cmd == $LC_LOAD_DYLINKER} {
            dylinker_command
        } elseif {$cmd == $LC_UUID} {
            uuid_command
        } elseif {$cmd == $LC_SOURCE_VERSION} {
            source_version_command
        } elseif {$cmd == $LC_MAIN} {
            entry_point_command
        } elseif {$cmd == $LC_LOAD_DYLIB} {
            dylib_command LC_LOAD_DYLIB
        } elseif {$cmd == $LC_FUNCTION_STARTS} {
            linkedit_data_command LC_FUNCTION_STARTS
        } elseif {$cmd == $LC_DATA_IN_CODE} {
            linkedit_data_command LC_DATA_IN_CODE
        } elseif {$cmd == $LC_REEXPORT_DYLIB} {
            dylib_command LC_REEXPORT_DYLIB
        } elseif {$cmd == $LC_ID_DYLIB} {
            dylib_command LC_ID_DYLIB
        } elseif {$cmd == $LC_SEGMENT_SPLIT_INFO} {
            linkedit_data_command LC_SEGMENT_SPLIT_INFO
        } elseif {$cmd == $LC_CODE_SIGNATURE} {
            linkedit_data_command LC_CODE_SIGNATURE
        } else {
            section "Unknown Command" {
                load_command_common;
                set size [expr $cmdsize - 8] 
                if {$size > 0 && $size <= [expr [len] - [pos]]} {
                    hex $size "body"
                } else {
                    entry "body" "N/A"
                }
            }
        }
    }
}


}
