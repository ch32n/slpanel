package require Tk

package provide slpanel 1.4

proc ::oo::Helpers::callback {method args} {
    list [uplevel 1 {namespace which my}] $method {*}$args
}

namespace eval slpanel {}

oo::class create slpanel::widget_interface {
    variable mainFrame slpanel itemConf winItem mainCanvas mainCanvasWidget defaultPanelOpt panelState
    
    
    #input args:
    #    -speed(70): open/close speed.
    #    -close(0):  if input is float(0-1) then value is used to show percentile of displayed area after closing window, if value > 1 it is used as pixels
    #    -open(0.5):
    #    -anchor(e): only e/w are supported 
    method add {PanelName args} {
        if [my PanelExists $PanelName] {
            return -code error "Error: Window '${PanelName}' already exists"
        }        
        
        set PanelOpt [dict merge $defaultPanelOpt $args]
        
        set Anchor   [dict get $PanelOpt -anchor]
        set Anchor   [string tolower $Anchor]
        switch -- $Anchor {
            e {
                set winItem($PanelName) [$mainCanvasWidget create window [expr {[winfo width $mainCanvas] + 1}] 0 -anchor ne]
            }
            w {
                set winItem($PanelName) [$mainCanvasWidget create window 0 0 -anchor nw]
            }
            default {
                return -code error "Error: Wrong anchor value '${Anchor}', should be 'e' or 'w'"
            }
        }
        
        set Frame     [ttk::frame $mainCanvas.fR[llength [winfo child $mainCanvas]]]
        set ContFrame [ttk::frame $Frame.fR]
        #
        dict set slpanel $PanelName frame     $Frame
        dict set slpanel $PanelName contframe $ContFrame
        #
        $mainCanvasWidget itemconfig $winItem($PanelName) -window $Frame
        $mainCanvasWidget itemconfig $winItem($PanelName) -height [winfo height $mainCanvas]
        #
        my AddPanel $PanelName $PanelOpt
        #
        ttk::separator $Frame.s -orient vertical
        #
        grid columnconfig $Frame 0 -weight 10
        grid rowconfig    $Frame 0 -weight 10
        grid $ContFrame  -column 0 -row 0 -sticky nesw
        grid $Frame.s    -column 1 -row 0 -sticky ns
        #
        return $ContFrame
    }    
    
    method remove {PanelName} {
        if ![my PanelExists $PanelName] {
            return
        }
            
        set Item [my GetPanelItemId $PanelName]
        $mainCanvasWidget delete $Item
        
        set ItemFrame [my GetItemFrame $PanelName]
        destroy $ItemFrame            
        
        dict unset slpanel $PanelName
        dict unset itemConf $Item
        unset winItem($PanelName)

        return
    }
    
    method itemcget {PanelName args} {
        my RequirePanelExists $PanelName
    
        if {[llength $args] != 1} {
            return -code error "wrong # args: should be 'cget option'"
        }
        
        return [my itemconfigure $PanelName {*}$args]
    }
    
    method itemconfigure {PanelName args} {
        my RequirePanelExists $PanelName
        
        set Item  [my GetPanelItemId $PanelName]
        
        if ![llength $args] {
            dict set RetOptionDict -speed  [dict get $itemConf $Item Speed]
            dict set RetOptionDict -open   [dict get $itemConf $Item 1 ratio]
            dict set RetOptionDict -close  [dict get $itemConf $Item 2 ratio]
            dict set RetOptionDict -anchor [dict get $itemConf $Item Anchor]
            
            return $RetOptionDict
        }
        
        if {[llength $args] == 1} {
            switch -- $args {
                -open {
                    return [dict get $itemConf $Item 1 ratio]
                }
                -close {
                    return [dict get $itemConf $Item 2 ratio]
                }
                -speed {
                    return [dict get $itemConf $Item Speed]
                }
                -anchor {
                    return [dict get $itemConf $Item Anchor]
                }
                default {
                    return -code error "Error: Invalid option '${args}'"
                }
            }
        }
        
        return [my ItemConfigure $PanelName $Item {*}$args]
    }
    
    method getpanels {} {
        return [dict keys $slpanel]
    }
    
    method getpanelstate {PanelName} {
        my RequirePanelExists $PanelName
        
        return [my GetPanelState $PanelName]
    }
    
    method openpanel {PanelName} {
        my PanelChangeState $PanelName $panelState(open)
    }
    
    method closepanel {PanelName} {
        my PanelChangeState $PanelName $panelState(closed)
    }
    
    method closeopened {} {
        foreach PanelName [my getpanels] {
            my closepanel $PanelName
        }
    }
    
    method togglepanel {PanelName} {
        my RequirePanelExists $PanelName
        
        set PanelState [my GetPanelState $PanelName]
        if {$PanelState == $panelState(open)} {
            my closepanel $PanelName
        } elseif {$PanelState == $panelState(closed)} {
            my openpanel $PanelName
        }
        
        return
    }
    
    method getmainframe {} {
        return $mainFrame
    }
    
    method getpanelframe {PanelName} {
        my RequirePanelExists $PanelName

        return [dict get $slpanel $PanelName contframe]
    }
}

oo::class create slpanel::q {
    variable Q
    
    constructor {args} {
        set Q [list]
        
        next {*}$args
    }
    #
    method AddToQ {PanelName PanelState} {
        lappend Q [list $PanelName $PanelState]
        return
    }
    #
    method DeQ {} {
        set Q [lreplace $Q 0 0]
        #
        return
    }
    #
    method FirtsInQ {} {
        return [lindex $Q 0]
    }
    #
    method CheckIfMyQ {PanelName PanelState} {
        lassign [my FirtsInQ] FItem FState
        #
        if {$PanelName eq $FItem && $PanelState eq $FState} {
            return 1
        }
        return 0
    }    
}

oo::class create slpanel::animate {
    variable mainCanvasWidget itemConf mainCanvas afterId animDelay ifbody panelState
    
    constructor {args} {
        set animDelay 15
        set afterId [list]
        
        dict set ifbody 1 {$W < $ReqW}
        dict set ifbody 0 {$W > $ReqW}
        dict set ifbody 2 {$W > $ReqW}        
        
        next {*}$args
    }    
    #
    method CancelAlphaEvent {} {
        catch {after cancel $afterId}
        return
    }
    #
    method SetlAlphaEvent {AfterId} {
        set afterId $AfterId
        #
        return
    }
    #
    method DoEvent {Item PanelName NewPanelState ContFrame ReqW Speed IfCmd W} {
        set W [expr {$W + $Speed}]
        #
        if $IfCmd {
            $mainCanvasWidget itemconf $Item -width $W
            #
            set Scr [info level [info level]]
            set Scr [lrange [lreplace $Scr end end $W] 1 end]
            #
            my SetlAlphaEvent [after $animDelay [callback {*}$Scr]]
        } else {
            $mainCanvasWidget itemconf $Item -width $ReqW
            
            if {$NewPanelState == $panelState(transition)} {
                my MainCnvItemState $PanelName $NewPanelState
            } elseif {$NewPanelState == $panelState(closed) && $ReqW < 2} {
                my MainCnvItemState $PanelName $NewPanelState
            }
            #
            dict set itemConf $Item Width $ReqW
            dict set itemConf $Item State $NewPanelState
            
            event generate $mainCanvas  <<slChangeDone>> -data $NewPanelState
            event generate $ContFrame   <<slChangeDone>> -data $NewPanelState
        }
        return
    }
    #
    method Animate {PanelName NewPanelState} {
        set Item [my GetPanelItemId $PanelName]
        #
        set PanelState [my GetPanelState $PanelName]
        #
        if {$PanelState != $NewPanelState} {
            #cancel event
            my CancelAlphaEvent
            #
            set ContFrame [my getpanelframe $PanelName]
            set ReqW      [my GetReqW $Item $NewPanelState]
            set IfCmd      [dict get $ifbody $NewPanelState]
            #
            set Speed [dict get $itemConf $Item Speed]
            set Speed [expr {round([my GetReqW $Item 1] / (100.0 / $animDelay))}]
            if !$Speed {set Speed 1}
            #
            set W [$mainCanvasWidget itemcget $Item -width]
            #
            if {$NewPanelState == $panelState(open)} {
                my MainCnvItemState $PanelName $NewPanelState
            } else {
                set Speed [expr {$Speed * -1}]
            }
            #
            event generate $mainCanvas  <<slChange>> -data $NewPanelState
            event generate $ContFrame   <<slChange>> -data $NewPanelState            
            #
            my DoEvent $Item $PanelName $NewPanelState $ContFrame $ReqW $Speed $IfCmd $W
        }
    }
    #
    method DeQWhenDone {PanelName PanelState} {
        if {[my GetPanelState $PanelName] == $PanelState} {
            my DeQ
        } else {
            after 10 [callback DeQWhenDone $PanelName $PanelState]
        }
        return
    }
    #
    method DoWhenPosible {PanelName PanelState} {
#        puts "DoWhenPosible $PanelName $PanelState"
        
        if [my CheckIfMyQ $PanelName $PanelState] {
            my Animate $PanelName $PanelState
            after 200 [callback DeQWhenDone $PanelName $PanelState]
        } else {
            after 30 [callback DoWhenPosible $PanelName $PanelState]
        }
        return
    }
}

oo::class create slpanel::widget {
    mixin slpanel::widget_interface slpanel::q slpanel::animate

    variable itemConf slpanel winItem mainCanvas mainCanvasWidget mainFrame defaultPanelOpt panelState
    
    constructor {Path args} {
        set defaultPanelOpt [dict merge [dict create -speed 70 -close 0 -open 0.5 -anchor e] $args]
        
        set slpanel [list]
        
        array set winItem {}
        
        set itemConf [dict create]
        
        array set panelState {
            closed 0
            open 1
            transition 2
        }
        
        my Init $Path
    }
    #
    method RequirePanelExists {PanelName} {
        if ![my PanelExists $PanelName] {
            return -code error "Error: Panel '${PanelName}' doesn't exists"
        }
        return
    }
    #
    method PanelChangeState {PanelName NewPanelState} {
        my RequirePanelExists $PanelName
        
        if {[my GetPanelState $PanelName] == $NewPanelState} {
            return
        }
        
        if [my CheckIfMyQ $PanelName $NewPanelState] {
            return
        }
        
        my AddToQ $PanelName $NewPanelState
        after 10 [callback DoWhenPosible $PanelName $NewPanelState]        
    
        return        
    }
    #
    method PanelExists {PanelName} {
        return [info exists winItem($PanelName)]
    }    
    #
    method GetPanelItemId {PanelName} {
        if [my PanelExists $PanelName] {
            return $winItem($PanelName)
        }
        #
        return
    }
    #
    method GetPanelState {PanelName} {
        set Item [my GetPanelItemId $PanelName]
        
        return [dict get $itemConf $Item State]    
    }
    #
    method ConfigCanvItemWidth {PanelName} {
        set Item [my GetPanelItemId $PanelName]
        set PanelState [my GetPanelState $PanelName]
        
        if {$PanelState == $panelState(open) || $PanelState == $panelState(closed)} {
            set ReqW [my GetReqW $Item [my GetPanelState $PanelName]]            
            $mainCanvasWidget itemconf $Item -width $ReqW            
        }
        
        return
    }
    #
    method UpdateReqW {Item PanelState} {
        set Ratio [dict get $itemConf $Item $PanelState ratio]
        if {$Ratio > 1} {
            set ReqW $Ratio
        } else {
            set ReqW [expr {int([winfo width $mainCanvas] * $Ratio) + 1}]
        }
        #
#        puts "UpdateReqW Item $Item State $PanelState --> MainW: [winfo width $mainCanvas] Ratio: $Ratio ReqW: $ReqW"
        #
        dict set itemConf $Item $PanelState ReqW $ReqW
        
        return
    }    
    #
    method MainCanvConfEvent {DisplayItem} {
        set ScrCanvH [winfo height $mainCanvas]
        set ScrCanvW [winfo width  $mainCanvas]
        #
        # puts "SL::WIN Configure event"
        #
        $mainCanvasWidget itemconfig $DisplayItem -height $ScrCanvH -width $ScrCanvW
        #
        foreach PanelName [my getpanels] {
            #
            set SwItem [my GetPanelItemId $PanelName]
            #
            $mainCanvasWidget itemconfig $SwItem -height $ScrCanvH
            
            set ItemAnchor [my GetAnchor $PanelName]
            switch -- $ItemAnchor {
                e {
                    $mainCanvasWidget coords $SwItem [expr {$ScrCanvW + 1}] 0
                }
                w {}
            }
            #        
            my UpdateReqW $SwItem $panelState(open)
            my UpdateReqW $SwItem $panelState(closed)
            #
            my ConfigCanvItemWidth $PanelName
        }
        return
    }    
    #
    method InitBind {DisplayItem} {
        set BindTag [string range $mainCanvas 1 end]
    #     set BindTag [join [list [file root $mainCanvas] Configure] _]
        bindtags $mainCanvas [list {*}[bindtags $mainCanvas] $BindTag]
        #
        bind $BindTag <Configure> [callback MainCanvConfEvent $DisplayItem]
        bind $BindTag <Destroy>   [callback destroy]
        #
        my MainCanvConfEvent $DisplayItem
        #
        return
    }
    #
    method Init {Path} {
        set mainCanvas [canvas $Path -borderwidth 0 -highlightthickness 0 -background white]
        rename $mainCanvas ${mainCanvas}_
        set mainCanvasWidget ${mainCanvas}_
        #
#        puts "mainCanvasWidget $mainCanvasWidget"
        #
        set mainFrame [ttk::frame $mainCanvas.cf]
        #
        set DisplayItem [$mainCanvasWidget create window 0 0 -anchor nw]
        $mainCanvasWidget itemconfig $DisplayItem -window $mainFrame
        #
        my InitBind $DisplayItem
        #
        return $mainCanvas
    }
    #
    method AddPanel {PanelName OptDict} {
        if [my PanelExists $PanelName] {
            #
            set Item [my GetPanelItemId $PanelName]
            dict set itemConf $Item State $panelState(transition)
            #
            my itemconfigure $PanelName {*}$OptDict
            #
            dict set itemConf $Item State $panelState(open)
            #
#            puts "ItemConfig [dict get $itemConf $Item]"
            #
            my closepanel $PanelName
        }
        #
        return
    }
    #
    method MainCnvItemState {PanelName PanelState} {
#       puts "Change vis $State"
        set Item      [my GetPanelItemId $PanelName]
        set ItemFrame [my GetItemFrame $PanelName]

        if {$PanelState == $panelState(open)} {
            $mainCanvasWidget itemconfig $Item -state normal
            raise $ItemFrame            
        } else {
            $mainCanvasWidget itemconfig $Item -state hidden
        }

        return
    }
    #
    method GetItemFrame {PanelName} {
        if [dict exists $slpanel $PanelName] {
            return [dict get $slpanel $PanelName frame]
        }
        return    
    }
    #
    method GetReqW {Item PanelState} {
        return [dict get $itemConf $Item $PanelState ReqW]
    }
    #
    method GetAnchor {PanelName} {
        set Item [my GetPanelItemId $PanelName]
        #
        return [dict get $itemConf $Item Anchor]
    }
    #
    method ItemConfigure {PanelName Item args} {
        dict for {Opt Val} $args {
            switch -- $Opt {
                -open {
                    dict set itemConf $Item $panelState(open) ratio $Val
                    my UpdateReqW $Item $panelState(open)
#                   puts "Item $PanelName Open Width [my GetReqW $Item 1]"
                    
                    my ConfigCanvItemWidth $PanelName
                }
                -close {
                    dict set itemConf $Item $panelState(transition) ratio 0
                    my UpdateReqW $Item $panelState(transition)
                    
                    dict set itemConf $Item $panelState(closed) ratio 0
                    my UpdateReqW $Item $panelState(closed)                 

                    if {$Val >= 0} {
                        dict set itemConf $Item $panelState(closed) ratio $Val
                        my UpdateReqW $Item $panelState(closed)
                        
                        my ConfigCanvItemWidth $PanelName
                    }
                    
#                    puts "Item $PanelName close Width [my GetReqW $Item 0]"
                }
                -speed {
                    dict set itemConf $Item Speed $Val
                }
                -anchor {
                    dict set itemConf $Item Anchor $Val
                }
                default {
                    return -code error "Error: Invalid option '${Opt}'"
                }
            }
        }
        
        return
    }    
}

proc slpanel::create {Path args} {
    set Obj [widget create tmp $Path {*}$args]
    
    rename $Obj ::$Path
    return $Path
}
