var noSleep = new NoSleep();

var wakeLockEnabled = false;
var toggleEl = document.querySelector("#toggle");
toggleEl.addEventListener('click', function() {
    if (!wakeLockEnabled) {
        noSleep.enable(); // keep the screen on!
        wakeLockEnabled = true;
        toggleEl.value = "Cook mode enabled";
        //          document.body.style.backgroundColor = "green";
    } else {
        noSleep.disable(); // let the screen turn off.
        wakeLockEnabled = false;
        toggleEl.value = "Cook mode disabled";
        //         document.body.style.backgroundColor = "";
    }
}, false);

function toggleWakeLock() {
    // Get the checkbox
    var checkBox = document.getElementById("check");
    // Get the output text
    var toggleEl = document.getElementById("toggle");
    // If the checkbox is checked, display the output text
    if (checkBox.checked == true) {
        noSleep.enable();
        toggleEl.value = "Wake lock enabled";
    } else {
        noSleep.disable();
        toggleEl.value = "Wake lock disabled";
    }
}
