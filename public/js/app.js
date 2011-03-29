var game = {
  state: 'none',
  timer_expires: null,
  last_command: -1
};

game.init = function(commands) {
  this.bind_events();
  this.process_commands(commands);

  setInterval('game.update_state()', 5000);
};

game.bind_events = function() {
  $('#start_buttons button').click(function() {
    game.send_command('start_game');
    return false;
  });

  $('#word_form form').submit(function() {
    var word = $.trim($('#word_form input').val().toLowerCase());

    var found = false;
    $('#words li').each(function(i, li) {
      if($(li).html() == word) { found = $(li); }
    });
    if(found) {
      found.effect('highlight');
    }
    else {
      var $word = $('<li>' + word + '</li>').addClass('waiting').hide();
      $('#words ul').append($word);
      $word.fadeIn();
      game.send_command('submit_word', {word: word});
    }
    $('#word_form input').val('');
    return false;
  });
};

game.send_command = function(command, data) {
  var last = this.last_command;
  if(last < 0) { last = 0; }
  $.ajax({
    url: '/game',
    type: 'post',
    data: {commands: [$.extend({}, {command: command}, data)], last_command: last},
    dataType: 'json',
    success: function(data, textStatus, jqXHR) {
      game.process_commands(data);
    },
    error: function(e) {
      log('ERROR', e);
    }
  });
};

game.process_commands = function(commands) {
  var self=this;
  $.each(commands, function(i, command) {
    log(command.cmd, command.seq, JSON.stringify(command));

    // if the server sends a command with a sequence starting at 0,
    // the game has been reset, and we're fine, the state change is handled.
    // otherwise, check to ensure we've not handled this command already, as
    // can sometimes happen with two simultaneous AJAX requests.
    if(command.seq > 0 && command.seq <= self.last_command) {
      return;
    }

    self.last_command = command.seq;
    switch(command.cmd) {

      // game state changes

      case 'game_waiting':
        self.state = 'waiting';
        $('#status').html("Waiting for players...");
        $('#time_remaining').fadeOut();
        $('#words li').remove();
        $('#players li').remove();
        $('#words').hide();
        $('#start_game').hide();
        $('#board td').html('');
        break;

      case 'game_starting':
        self.state = 'starting';
        $('#status').html("Game starting...");
        $('#time_remaining').fadeIn();
        $('#start_game').fadeOut();
        var expires = Date.parse(command.expires);
        var diff = expires - Date.now();
        setTimeout('game.update_state()', diff);
        self.start_timer(expires);

        break;

      case 'game_begin':
        self.state = 'in_process';
        $('#status').html('Game on!');
        var expires = Date.parse(command.expires);
        var diff = expires - Date.now();
        setTimeout('game.update_state()', diff);
        self.start_timer(expires);

        $.each(command.board, function(i, cube) {
          $($('#board td')[i]).html(cube);
        });

        $('#start_game').hide();
        $('#words').fadeIn();
        $('#word_form').fadeIn();
        $('#word_form input').focus().select();

        break;

      case 'game_vote':
        self.state = 'voting';
        $('#status').html('Vote!');
        $.each(command.board, function(i, cube) {
          $($('#board td')[i]).html(cube);
        });

        $('#words').fadeOut();
        $('#word_form').fadeOut();

        break;

      case 'game_results':
        self.state = 'results';
        $('#status').html('Final results');
        $.each(command.board, function(i, cube) {
          $($('#board td')[i]).html(cube);
        });
        $('#time_remaining').fadeOut();

        $('#words').fadeOut();
        $('#word_form').fadeOut();


        break;


      // player-related:

      case 'player_join':
        var id = 'player_' + command.id;
        if(!$('#' + id).length) {
          var $li = $('<li id="' + id + '" style="display:none;">' + command.name + '</li>');
          $('#players ul').append($li);
          $li.fadeIn();
        }

        if(game.state == 'waiting') {
          if($('#players li').length > 1) {
            $('#start_game').fadeIn();
          }
          else {
            $('#start_game').hide();
          }
        }
        break;

      case 'player_leave':
        break;

      // word submission

      case 'accept_word':
        // server accepted a word
        var found = false;
        $('#words li.waiting').each(function(i,li) {
          if($(li).html() == command.word) {
            found = true;
            $(li).removeClass('waiting');
          }
        });
        if(!found) {
          var $word = $('<li>' + command.word + '</li>').hide();
          $('#words ul').append($word);
          $word.fadeIn();
        }
        break;

      case 'reject_word':
        // server rejected a word
        $('#words li.waiting').each(function(i,li) {
          if($(li).html() == command.word) {
            $(li).removeClass('waiting').addClass('invalid').fadeOut(function() {
              $(this).remove();
            });
          }
        });
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

game.update_state = function() {
  $.ajax({
    url: '/game.json',
    type: 'get',
    data: {last_command: game.last_command},
    dataType: 'json',
    success: function(data, textStatus, jqXHR) {
      game.process_commands(data);
    },
    error: function(e) {
      log('ERROR', e);
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


