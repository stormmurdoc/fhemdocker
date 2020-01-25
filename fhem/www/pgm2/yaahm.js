//########################################################################################
// yaahm.js
// Version 3.0beta4
// See 95_YAAHM for licensing
//########################################################################################
//# Prof. Dr. Peter A. Henning

//------------------------------------------------------------------------------------------------------
// Determine csrfToken
//------------------------------------------------------------------------------------------------------

var req = new XMLHttpRequest();
req.open('GET', document.location.href, false);
req.send(null);
var csrfToken = req.getResponseHeader('X-FHEM-csrfToken');
if( csrfToken == null ){
    csrfToken = "null";
}

//------------------------------------------------------------------------------------------------------
// encode Parameters for URL
//------------------------------------------------------------------------------------------------------

function encodeParm(oldval) {
    var newval;
    newval = oldval.replace(/"/g, '%27');
    newval = newval.replace(/#/g, '%23');
    newval = newval.replace(/\+/g, '%2B');
    newval = newval.replace(/&/g, '%26');
    newval = newval.replace(/'/g, '%27');
    newval = newval.replace(/=/g, '%3D');
    newval = newval.replace(/\?/g, '%3F');
    newval = newval.replace(/\|/g, '%7C');
    return newval;
}

// Tool Tips
//  $( function() {
//    $( document ).tooltip();
//  } );

//------------------------------------------------------------------------------------------------------
// Expand text box
//------------------------------------------------------------------------------------------------------

$(function () {
    $(".expand").focus(function () {
        $(this).animate({
            width: '200px'
        },
        "slow")
    });
});

$(function () {
    $(".expand").blur(function () {
        $(this).animate({
            width: '100px'
        },
        "slow")
    });
});

//------------------------------------------------------------------------------------------------------
// Write the Attribute Value
//------------------------------------------------------------------------------------------------------

function yaahm_setAttribute(name, attr, val) {
    //set Yaahm Attribute
    var location = document.location.pathname;
    if (location.substr(location.length -1, 1) == '/') {
        location = location.substr(0, location.length -1);
    }
    var url = document.location.protocol + "//" + document.location.host + location;
    FW_cmd(url + '?XHR=1&fwcsrf=' + csrfToken + '&cmd.' + name + '=attr ' + name + ' ' + encodeParm(attr) + ' ' + encodeParm(val));
}

//------------------------------------------------------------------------------------------------------
// Change mode and state, set next time
//------------------------------------------------------------------------------------------------------

var hsold;
var hmold;

function yaahm_mode(name, targetmode) {
    var location = document.location.pathname;
    if (location.substr(location.length -1, 1) == '/') {
        location = location.substr(0, location.length -1);
    }
    var url = document.location.protocol + "//" + document.location.host + location;
    
    FW_cmd(url + '?XHR=1&fwcsrf=' + csrfToken + '&cmd.' + name + '={main::YAAHM_mode("' + name + '","' + targetmode + '")}');
}

function yaahm_state(name, targetstate) {
    var location = document.location.pathname;
    if (location.substr(location.length -1, 1) == '/') {
        location = location.substr(0, location.length -1);
    }
    var url = document.location.protocol + "//" + document.location.host + location;
    
    FW_cmd(url + '?XHR=1&fwcsrf=' + csrfToken + '&cmd.' + name + '={main::YAAHM_state("' + name + '","' + targetstate + '")}');
}

function yaahm_setnext(name, i) {
    var location = document.location.pathname;
    if (location.substr(location.length -1, 1) == '/') {
        location = location.substr(0, location.length -1);
    }
    var url = document.location.protocol + "//" + document.location.host + location;
    
    var nval;
    if (document.getElementById('wt' + i + '_n') !== null) {
        nval = document.getElementById('wt' + i + '_n').value;
    } else {
        nval = "undef";
    }
    
    FW_cmd(url + '?XHR=1&fwcsrf=' + csrfToken + '&cmd.' + name + '={main::YAAHM_nextWeeklyTime("' + name + '","next_' + i + '","' + nval + '")}');
}

//------------------------------------------------------------------------------------------------------
// Write field value for next - first two here, the others dynamically
//------------------------------------------------------------------------------------------------------

$("body").on('DOMSubtreeModified', "#wt0_o",
  function () {
        nval = document.getElementById("wt0_o").innerHTML;
        document.getElementById("wt0_n").value = nval;
    })

$("body").on('DOMSubtreeModified', "#wt1_o",
  function () {
        nval = document.getElementById("wt1_o").innerHTML;
        document.getElementById("wt1_n").value = nval;
    })

//------------------------------------------------------------------------------------------------------
// Animate housestate icon
//------------------------------------------------------------------------------------------------------

var blinker;
var hsfill;
var hscolor;

function blinkhs() {
    var w = document.getElementById("wid_hs");
    if (w) {
        if (hsfill == hscolor) {
            hsfill = "white";
            w.getElementsByClassName("hs_is")[0].setAttribute("fill", "white");
        } else {
            hsfill = hscolor;
            w.getElementsByClassName("hs_is")[0].setAttribute("fill", hscolor);
        }
    }
}

$("body").on('DOMSubtreeModified', "#sym_hs",
function () {
    var w = document.getElementById("wid_hs");
    if (w) {
        var symnew = document.getElementById("sym_hs").innerHTML;
        if (blinking == 1 && symnew.includes("green")) {
            clearInterval(blinker);
            blinking = 0;
            w.getElementsByClassName("hs_is")[0].setAttribute("fill", hscolor);
        } else {
            if (blinking == 0 && ! symnew.includes("green")) {
                hscolor = w.getElementsByClassName("hs_is")[0].getAttribute("fill");
                blinker = setInterval('blinkhs()', 1000);
                blinking = 1;
            }
        }
    }
})

$("body").on('DOMSubtreeModified', "#hid_hs",
function () {
    var hsnew = document.getElementById("hid_hs").innerHTML;
    if (hsnew != hsold) {
        hsold = hsnew;
        var w = document.getElementById("wid_hs");
        if (w) {
            switch (hsnew) {
                case "unsecured":
                hscolor = csstate[0];
                w.getElementsByClassName("hs_is")[0].setAttribute("fill", csstate[0]);
                w.getElementsByClassName("hs_smb")[0].setAttribute("visibility", "hidden");
                w.getElementsByClassName("hs_unlocked")[0].setAttribute("visibility", "visible");
                w.getElementsByClassName("hs_locked")[0].setAttribute("visibility", "hidden");
                w.getElementsByClassName("hs_eye")[0].setAttribute("visibility", "hidden");
                break;
                case "secured":
                hscolor = csstate[1];
                w.getElementsByClassName("hs_is")[0].setAttribute("fill", csstate[1]);
                w.getElementsByClassName("hs_smb")[0].setAttribute("visibility", "hidden");
                w.getElementsByClassName("hs_unlocked")[0].setAttribute("visibility", "hidden");
                w.getElementsByClassName("hs_locked")[0].setAttribute("visibility", "visible");
                w.getElementsByClassName("hs_eye")[0].setAttribute("visibility", "hidden");
                break;
                case "protected":
                hscolor = csstate[2];
                w.getElementsByClassName("hs_is")[0].setAttribute("fill", csstate[2]);
                w.getElementsByClassName("hs_smb")[0].setAttribute("visibility", "visible");
                w.getElementsByClassName("hs_unlocked")[0].setAttribute("visibility", "hidden");
                w.getElementsByClassName("hs_locked")[0].setAttribute("visibility", "visible");
                w.getElementsByClassName("hs_eye")[0].setAttribute("visibility", "hidden");
                break;
                case "guarded":
                hscolor = csstate[3];
                w.getElementsByClassName("hs_is")[0].setAttribute("fill", csstate[3]);
                w.getElementsByClassName("hs_smb")[0].setAttribute("visibility", "visible");
                w.getElementsByClassName("hs_unlocked")[0].setAttribute("visibility", "hidden");
                w.getElementsByClassName("hs_locked")[0].setAttribute("visibility", "visible");
                w.getElementsByClassName("hs_eye")[0].setAttribute("visibility", "visible");
                break;
            }
        } else {
            alert("state widget not found");
        }
    }
});

$("body").on('DOMSubtreeModified', "#hid_hm",
function () {
    var hmnew = document.getElementById("hid_hm").innerHTML;
    if (hmnew != hmold) {
        hmold = hmnew;
        var w = document.getElementById("wid_hm");
        if (w) {
            switch (hmnew) {
                case "normal":
                w.getElementsByClassName("hm_is")[0].setAttribute("fill", csmode[0]);
                w.getElementsByClassName("hm_n")[0].setAttribute("visibility", "visible");
                w.getElementsByClassName("hm_p")[0].setAttribute("visibility", "hidden");
                w.getElementsByClassName("hm_a")[0].setAttribute("visibility", "hidden");
                w.getElementsByClassName("hm_dnd")[0].setAttribute("visibility", "hidden");
                break;
                case "party":
                w.getElementsByClassName("hm_is")[0].setAttribute("fill", csmode[1]);
                w.getElementsByClassName("hm_n")[0].setAttribute("visibility", "hidden");
                w.getElementsByClassName("hm_p")[0].setAttribute("visibility", "visible");
                w.getElementsByClassName("hm_a")[0].setAttribute("visibility", "hidden");
                w.getElementsByClassName("hm_dnd")[0].setAttribute("visibility", "hidden");
                break;
                case "absence":
                w.getElementsByClassName("hm_is")[0].setAttribute("fill", csmode[2]);
                w.getElementsByClassName("hm_n")[0].setAttribute("visibility", "hidden");
                w.getElementsByClassName("hm_p")[0].setAttribute("visibility", "hidden");
                w.getElementsByClassName("hm_a")[0].setAttribute("visibility", "visible");
                w.getElementsByClassName("hm_dnd")[0].setAttribute("visibility", "hidden");
                break;
                case "donotdisturb":
                w.getElementsByClassName("hm_is")[0].setAttribute("fill", csmode[3]);
                w.getElementsByClassName("hm_n")[0].setAttribute("visibility", "hidden");
                w.getElementsByClassName("hm_p")[0].setAttribute("visibility", "hidden");
                w.getElementsByClassName("hm_a")[0].setAttribute("visibility", "hidden");
                w.getElementsByClassName("hm_dnd")[0].setAttribute("visibility", "visible");
                break;
            }
        } else {
            alert("mode widget not found");
        }
    }
});

//------------------------------------------------------------------------------------------------------
// Device Action 
//------------------------------------------------------------------------------------------------------

function yaahm_startDeviceAction(name) {
    
    var location = document.location.pathname;
    if (location.substr(location.length -1, 1) == '/') {
        location = location.substr(0, location.length -1);
    }
    var url = document.location.protocol + "//" + document.location.host + location;
    
    // saving event, earliest and latest
    // iterate over different device actions
    for (var i = 0; i < devactno; i++) {
        var dev, evt;
        var eval, lval, xval;
        if (document.getElementById('xt' + i + '_n') !== null) {
            dev = encodeParm(document.getElementById('xt' + i + '_n').innerHTML);
        } else {
            dev = "undef"
        }
        if (document.getElementById('xt' + i + '_v') !== null) {
            evt = encodeParm(document.getElementById('xt' + i + '_v').value);
        } else {
            evt = "undef"
        }
        if (document.getElementById('xt' + i + '_e') !== null) {
            eval = encodeParm(document.getElementById('xt' + i + '_e').value);
        } else {
            eval = "undef"
        }
        if (document.getElementById('xt' + i + '_l') !== null) {
            lval = encodeParm(document.getElementById('xt' + i + '_l').value);
        } else {
            lval = "undef"
        }
        //action
        if (document.getElementById('xt' + i + '_x') !== null) {
            xval = encodeParm(document.getElementById('xt' + i + '_x').value);
        } else {
            xval = "undef"
        }
    
        
        FW_cmd(url + '?XHR=1&fwcsrf=' + csrfToken + '&cmd.' + name + '={main::YAAHM_setParm("' + name + '","xt","' + i + '","' + dev + '","' + evt + '","' + eval + '","' + lval + '","' + xval + '")}');
    }
    // really start it now
    FW_cmd(url + '?XHR=1&fwcsrf=' + csrfToken + '&cmd.' + name + ' ={main::YAAHM_startDeviceActions("' + name + '")}');
    
}

//------------------------------------------------------------------------------------------------------
// Start the daily timer
//------------------------------------------------------------------------------------------------------

function yaahm_startDayTimer(name) {
    
    var location = document.location.pathname;
    if (location.substr(location.length -1, 1) == '/') {
        location = location.substr(0, location.length -1);
    }
    var url = document.location.protocol + "//" + document.location.host + location;
    
    // saving start and end times
    for (var i = 0; i < dailyno; i++) {
        var sval, eval, xval, aval1, aval2;
        if ((dailykeys[i] != 'wakeup') && (dailykeys[i] != 'sleep')) {
            if (document.getElementById('dt' + dailykeys[i] + '_s') !== null) {
                sval = document.getElementById('dt' + dailykeys[i] + '_s').value;
            } else {
                sval = "undef"
            }
            if (document.getElementById('dt' + dailykeys[i] + '_e') !== null) {
                eval = document.getElementById('dt' + dailykeys[i] + '_e').value;
            } else {
                eval = "undef"
            }
            if (document.getElementById('dt' + dailykeys[i] + '_x') !== null) {
                xval = encodeParm(document.getElementById('dt' + dailykeys[i] + '_x').value);
            } else {
                xval = "undef"
            }
            aval1 = $("input[name='actim" + dailykeys[i] + "']:checked").map(function () {
                return $(this).val();
            }).get();
            aval2 = $("input[name='actid" + dailykeys[i] + "']:checked").map(function () {
                return $(this).val();
            }).get();
            FW_cmd(url + '?XHR=1&fwcsrf=' + csrfToken + '&cmd.' + name + '={main::YAAHM_setParm("' + name + '","dt","' + dailykeys[i] + '",' + '"' + sval + '","' + eval + '","' + xval + '","' + aval1 + ';' + aval2 + '")}');
        }
    }
    // really start it now
    FW_cmd(url + '?XHR=1&fwcsrf=' + csrfToken + '&cmd.' + name + ' ={main::YAAHM_startDayTimer("' + name + '")}');
    
    // change link
    $('#dtlink').html('<a href="/fhem?detail=' + name + '.dtimer.IF">' + name + '.dtimer.IF</a>');
}

//------------------------------------------------------------------------------------------------------
// daytype logic
//------------------------------------------------------------------------------------------------------

function yaahm_dtlogic(i,dt) {
    //i = timer number, j = daytype number
    //has it been checked ? 
    //activity vacation/holiday
    var aval;
    //modify input field
    var field = document.getElementById('wt' + dt + i + '_s');
    if (field !== null) {
      var checkBox = document.getElementById('acti_' + dt + i + '_d');
      if (checkBox.checked == true){
        field.value = '';
        field.disabled = true; 
      }else{       
        field.disabled = false;
      }
    }
}

//------------------------------------------------------------------------------------------------------
// Weekly profile
//------------------------------------------------------------------------------------------------------

function yaahm_startWeeklyTimer(name) {
    
    var location = document.location.pathname;
    if (location.substr(location.length -1, 1) == '/') {
        location = location.substr(0, location.length -1);
    }
    var url = document.location.protocol + "//" + document.location.host + location;
    
    // saving start weekly times
    // iterate over different weekly tables
    for (var i = 0; i < weeklyno; i++) {
        var xval;
        var nval;
        var aval1, aval2;
        var sval =[ "", "", "", "", "", "", "", "", ""];
        //action
        if (document.getElementById('wt' + i + '_x') !== null) {
            xval = encodeParm(document.getElementById('wt' + i + '_x').value);
        } else {
            xval = "undef"
        }
        //next time - attention, field is in toptable
        if (document.getElementById('wt' + i + '_n') !== null) {
            nval = document.getElementById('wt' + i + '_n').value;
        } else {
            nval = "undef"
        }
        //activity party/absence
        aval1 = $("input[name='acti_" + i + "_m']:checked").map(function () {
            return $(this).val();
        }).get();
        //activity vacation/holiday
        aval2 = $("input[name='acti_" + i + "_d']:checked").map(function () {
            return $(this).val();
        }).get();
        
        //iterate over days of week
        for (var j = 0; j < 9; j++) {
            if (document.getElementById('wt' + weeklykeys[j] + i + '_s') !== null) {
                sval[j] = document.getElementById('wt' + weeklykeys[j] + i + '_s').value;
            } else {
                sval[j] = "undef";
            }
        }
        
        FW_cmd(url + '?XHR=1&fwcsrf=' + csrfToken + '&cmd.' + name + '={main::YAAHM_setParm("' + name + '","wt","' + i + '","' + xval + '","' + nval + '","' + aval1 + '","' + aval2 + '","' + sval.join('","') + '")}');
    }
    // really start it now
    FW_cmd(url + '?XHR=1&fwcsrf=' + csrfToken + '&cmd.' + name + ' ={main::YAAHM_startWeeklyTimer("' + name + '")}');
    
    // change links
    for (var i = 0; i < weeklyno; i++) {
        $('#wt' + i + 'link').html('<a href="fhem?detail=' + name + '.wtimer_' + i + '.IF">' + name + '.wtimer_' + i + '.IF</a>');
    }
}