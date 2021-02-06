
$(document).ready(function(){
  $('body').css('background-image','url()');
  $('#logo').replaceWith( '<canvas id="clock" width="175" height="175"> Fehlermeldung </canvas>');


  loadScript("pgm2/station-clock.js", function() {
    var clock = new StationClock("clock");
    clock.body = StationClock.RoundBody;
    clock.dial = StationClock.SwissStrokeDial;
    clock.hourHand = StationClock.SwissHourHand;
    clock.minuteHand = StationClock.SwissMinuteHand;
    clock.secondHand = StationClock.SwissSecondHand;
    clock.boss = StationClock.NoBoss;
    clock.minuteHandBehavoir = StationClock.BouncingMinuteHand;
    clock.secondHandBehavoir = StationClock.OverhastySecondHand;

    function animate(clock) {
      clock.draw();
      window.setTimeout(function(){animate(clock)}, 50);
    }

    animate(clock);

  }, true);

});
