var game = {
  state: 'waiting',
  timer_expires: null
};

game.init = function(commands) {
  this.handle(commands);
};

game.handle = function(commands) {
  var self=this;
  $.each(commands, function(i, command) {
    switch(command.cmd) {

      // game state changes

      case 'game_waiting':
        self.state = 'waiting';
        $('#status').html("Waiting for players...");
        var expires = Date.parse(command.started).add({seconds: command.remaining});
        var diff = expires - Date.now();
        // setTimeout('game.update_state()', diff);
        self.start_timer(expires);
        break;

      case 'game_starting':
        break;

      case 'game_begin':
        break;

      case 'game_vote':
        break;

      case 'game_score':
        // display full scoring information about who 
        break;


      // player-related:

      case 'player_join':
        var id = 'player_' + command.id;
        if(!$('#' + id).length) {
          var $li = $('<li id="' + id + '" style="display:none;">' + command.name + '</li>');
          $('#players ul').append($li);
          $li.fadeIn();
        }
        break;

      case 'player_leave':
        break;

      // word submission

      case 'submit_word':
        // player submitted a word
        break;

      case 'accept_word':
        // server accepted a word
        break;

      case 'reject_word':
        // server rejected a word
        break;

      // voting

      case 'vote':
        // voting on a word
        break;

      case 'player_vote':
        break;

      default:
        log('unknown command', command.cmd, command);
        break;
    }
  });
};

game.start_timer = function(expires) {
  this.timer_expires = expires;
  setTimeout(this.update_timer, 100);
  var diff = expires - Date.now();
  $('#time_remaining').fadeIn();
  $('#time_remaining span').html(Date.today().add({milliseconds: diff}).toString('mm:ss'));
};

game.update_timer = function() {
  var now = Date.now();
  if(now >= game.timer_expires) {
    $('#time_remaining span').html('...');
  }
  else {
    var diff = game.timer_expires - now;
    $('#time_remaining span').html(Date.today().add({milliseconds: diff}).toString('mm:ss'));
    setTimeout('game.update_timer()', 100);
  }
};

// html5 boilerplate
window.log = function(){
  log.history = log.history || [];
  log.history.push(arguments);
  if(this.console){
    console.log( Array.prototype.slice.call(arguments) );
  }
};
(function(doc){
  var write = doc.write;
  doc.write = function(q){
    log('document.write(): ',arguments);
    if (/docwriteregexwhitelist/.test(q)) write.apply(doc,arguments);
  };
})(document);


