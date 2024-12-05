var noSleep = new NoSleep();

var wakeLockEnabled = false;

function toggleWakeLock() {
    // Get the checkbox
    var checkBox = document.getElementById("check");
    // Get the output text
    var toggleEl = document.getElementById("toggle");
    // If the checkbox is checked, display the output text
    if (checkBox.checked == true) {
        noSleep.enable();
        toggleEl.value = "Kochmodus ausschalten ";
    } else {
        noSleep.disable();
        toggleEl.value = "Kochmodus einschalten ";
    }
}
