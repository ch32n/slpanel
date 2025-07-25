# Slpanel
Tcl/Tk megawidget that provides animated, collapsible side panels.

![slpanel](https://github.com/user-attachments/assets/81faf9ef-fb9f-47c1-9d86-c47bc76b48d7)

## Command Reference

**slpanel::create** *pathName* ?options?</br>
Creates sliding panel megawidget</br>
  
## Widget Commands

*pathName* **add** *PanelName* ?options?</br>
  Adds new panel with name PanelName. PanelName is a unique string to identify the panel.</br>
  Returns the path to the panel's content frame, where you should pack your widgets.</br>
  Configuration Options:</br>
   - **-anchor** (e|w): (Default: e) The side the panel slides from.</br>
   - **-open** (float|integer): (Default: 0.5) The width of the open panel. A value between 0.0 and 1.0 is a percentage of the main area; a value > 1 is a fixed pixel size.</br>
   - **-close** (float|integer): (Default: 0) The width of the closed panel, allowing a small part to remain visible. Sizing rules are the same as for -open.</br>
   - **-speed** (integer): (Default: 70) A parameter controlling the animation speed. Higher is faster</br>

*pathName* **remove** *PanelName*</br>
 Destroys a panel and its content.</br>

*pathName* **itemconfigure** *PanelName* ?options? ?value?</br>
 Configures an existing panel. If called with no options, returns a dictionary of all options. If called with a single option, returns its value.</br>

*pathName* **itemcget** *PanelName* option</br>
 Returns the value of a single configuration option for the specified panel.</br>

*pathName* **openpanel** *PanelName*</br>
 Starts the animation to open a panel.</br>

*pathName* **closepanel** *PanelName*</br>
 Starts the animation to close a panel.</br>

*pathName* **togglepanel** *PanelName*</br>
 Opens a closed panel or closes an open one.</br>

*pathName* **closeopened**</br>
 Closes all currently open panels.</br>

*pathName* **getpanels**</br>
 Returns a list of all panel names.</br>

*pathName* **getpanelstate** *PanelName*</br>
 Returns the current state of a panel.</br>
 Values:</br>
  1: Open</br>
  0: closed</br>
  
*pathName* **getmainframe**</br>
 Returns the path to the central content frame.</br>

*pathName* **getpanelframe** *PanelName*</br>
 Returns the path to the content frame for a specific panel.</br>


## Virtual Events</br>
slpanel generates virtual events on the panel's content frame to allow you to react to state changes.</br>
`<<slChange>>`: Generated when an animation begins.</br>
`<<slChangeDone>>`: Generated when an animation is complete.</br>
The new state (0 or 1) is passed in the event's -data field, which can be accessed with the %d substitution.</br>

### Example:
```tcl
set panelFrame [$panels getpanelframe myPanel]
bind $panelFrame <<slChangeDone>> {
    if {%d == 1} {
        puts "myPanel has finished opening!"
    }
}
```

## Example:
```tcl
package require slpanel

set buttonFrame   [ttk::frame .bf]
set toggle1 [ttk::button $buttonFrame.b1 -text "toggle 1"]
set toggle2 [ttk::button $buttonFrame.b2 -text "toggle 2"]
set close   [ttk::button $buttonFrame.b3 -text "close all"]

grid $buttonFrame -row 0 -column 0 -sticky nsw
grid $toggle1     -row 0 -column 0 -sticky nw
grid $toggle2     -row 1 -column 0 -sticky nw
grid $close       -row 2 -column 0 -sticky nw

# create sliding panel container
set slPanel [slpanel::create .slPanel]
grid $slPanel -row 0 -column 1 -sticky nesw

grid rowconfigure     . 0 -weight 1
grid columnconfigure  . 1 -weight 1

# get sliding panel main frame
set mainFrame  [$slPanel getmainframe]
grid rowconfigure     $mainFrame 0 -weight 1
grid columnconfigure  $mainFrame 0 -weight 1

# create canvas on sliding panel main frame
set maincFcanv [canvas $mainFrame.mCanvas -background white]
grid $maincFcanv -row 0 -column 0 -sticky nesw


# add 2 sliding panels
set slFrame1 [$slPanel add sl1 -speed 130 -close 0.2 -anchor e -open 0.5]
set slFrame2 [$slPanel add sl2 -speed 10  -anchor e -open [winfo pixels . 7c] ]

# bind sliding panel frames virtual events on state change
foreach slFrame [list $slFrame1 $slFrame2] {
	bind $slFrame <<slChange>>     [list puts "Started state change on slFrame: $slFrame new state: %d"]	
	bind $slFrame <<slChangeDone>> [list puts "State change done on slFrame: $slFrame new state: %d"]	
}

#create widgets in sliding panels
set maincFcanv1 [canvas $slFrame1.slCanvas1 -background red]

grid $maincFcanv1 -row 0  -column 0 -sticky nesw
grid rowconfigure    $slFrame1 0 -weight 1
grid columnconfigure $slFrame1 0 -weight 1


set maincFcanv2 [canvas $slFrame2.slCanvas2 -background green]

grid $maincFcanv2 -row 0  -column 0 -sticky nesw
grid rowconfigure    $slFrame2 0 -weight 1
grid columnconfigure $slFrame2 0 -weight 1

# close sliding panels when button1 click on main frame
bind $maincFcanv <Button-1> [list $slPanel closeopened]

# configure buttons
$toggle1 configure -command [list $slPanel togglepanel sl1]
$toggle2 configure -command [list $slPanel togglepanel sl2]
$close   configure -command [list $slPanel closeopened]
```
