/*
 * Entry point for the companion app
 */
import { settingsStorage } from "settings";
import * as messaging from "messaging";
import { me } from "companion";

console.log("Companion code started");

// Event fires when a setting is changed
settingsStorage.onchange = function(evt) {
  // Which setting changed
  console.log("key: " + evt.key)

  // What was the old value
  console.log("old value: " + evt.oldValue)

  // What is the new value
  console.log("new value: " + evt.newValue)
  sendSettingsToDevice()
}

if (me.launchReasons.settingsChanged) {
  // Settings were changed while the companion was not running
  sendSettingsToDevice()
}

function sendSettingsToDevice() {
    let action = {
        action: 'updateSettings',
        settings: {
            useMetricUnits: settingsStorage.getItem('useMetricUnits')
        }
    }
    if (messaging.peerSocket.readyState === messaging.peerSocket.OPEN) {
        messaging.peerSocket.send(action);
    } else {
        console.log("No peerSocket connection");
    }
}
