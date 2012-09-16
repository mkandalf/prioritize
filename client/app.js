// Generated by CoffeeScript 1.3.1
(function() {
  'use strict';

  var $loading, COMPOSE_PATH_REGEX, DEBUG, EMAIL_PATH_REGEX, MAIN_FRAME_SELECTOR, PAYMENT_FIELD_REGEX, email, iframe, inbox, loadingTimer, modal, onSignupComplete, payment, renderInActionBar, renderValueLogo, template,
    _this = this;

  console.log('Value for Gmail extension script loaded');

  MAIN_FRAME_SELECTOR = '#canvas_frame';

  PAYMENT_FIELD_REGEX = /^\[\$[+-]?[0-9]{1,3}(?:,?[0-9]{3})*(?:\.[0-9]{2})?\]/;

  COMPOSE_PATH_REGEX = /compose/;

  EMAIL_PATH_REGEX = /#inbox\/[a-f|0-9]+$/;

  window.addEventListener('hashchange', function() {
    if (window.location.hash.match(COMPOSE_PATH_REGEX)) {
      return payment.renderButton();
    } else if (window.location.hash.match(EMAIL_PATH_REGEX)) {
      return email.read();
    } else if (window.location.hash.match(/^#inbox$/)) {
      return inbox.sort();
    }
  });

  template = function(domId) {
    return _.template(($("#" + domId).html() || "").trim());
  };

  iframe = {
    isLinked: false,
    linkCSS: function($frame) {
      if (iframe.isLinked) {
        return null;
      }
      return $frame.contents().find('head').append($('<link/>', {
        rel: 'stylesheet',
        type: 'text/css',
        href: chrome.extension.getURL('gmail_canvas.css')
      }).load(function() {
        console.log('loaded css');
        return iframe.isLinked = true;
      }));
    }
  };

  renderInActionBar = function(el) {
    var $actions, $frame;
    $frame = $(MAIN_FRAME_SELECTOR);
    $actions = $frame.contents().find('#\\:ro > div:visible').find('[role=button]').first().parent();
    $actions.children('span').remove();
    $actions.children().last().before(el);
    return $actions;
  };

  payment = {
    renderButton: function() {
      var $actions, $frame, $paymentField, $sendEmail, PAYMENT_BUTTON;
      PAYMENT_BUTTON = '<div id="payment-button">$<input tabindex="2" type="text" name="pay_amount" /></div>';
      $frame = $(MAIN_FRAME_SELECTOR);
      $actions = $frame.contents().find('#\\:ro [role=button] > b').parent().parent();
      $actions.children('span').remove();
      $actions.children().last().before(PAYMENT_BUTTON);
      $paymentField = $actions.find('#payment-button input');
      $paymentField.on('click', function(e) {
        return $(this).focus();
      });
      $paymentField.on('blur', function(e) {
        return payment.amount = $(this).val();
      });
      $sendEmail = $actions.children().first();
      $sendEmail.on('mousedown', function(e) {
        var $subject, $to_emails, $value;
        $value = $paymentField.val();
        $subject = $frame.contents().find('input[name=subject]');
        $subject.val("[$" + $value + "] " + ($subject.val()));
        $to_emails = $frame.contents().find('textarea[name="to"]').val();
        console.log($to_emails, $value);
        return _.each($to_emails.split(','), function($to) {
          $to = $to.trim();
          return chrome.extension.sendMessage({
            method: "getUser",
            email: $to
          }, function($data) {
            console.log($data);
            return chrome.extension.sendMessage({
              method: "makePayment",
              to: $data.user,
              amount: $value
            });
          });
        });
      });
      return null;
    }
  };

  inbox = {
    sorted: false,
    fakes: [],
    emails: [],
    sort: function() {
      var animate_emails, build_fakes, canonical_table, get_emails, hide_fakes, move_emails, sort_emails, toggle_fakes;
      if (_this.sorted || !window.location.hash.match(/^#inbox$/)) {
        return;
      }
      _this.sorted = true;
      canonical_table = $(MAIN_FRAME_SELECTOR).contents().find('table > colgroup').eq(0).parent();
      get_emails = function() {
        var $emails;
        $emails = canonical_table.find('tr');
        return _this.emails = _.map($emails, function(email, i) {
          var subject, value;
          subject = ($(email)).find('td[role=link] div > span:first-child').text();
          value = subject.match(PAYMENT_FIELD_REGEX);
          if (value != null) {
            value = parseFloat(value[0].slice(2, -1));
          } else {
            value = 0;
          }
          return {
            node: $(email),
            subject: subject,
            value: value,
            index: i,
            dest: -1,
            fake: null,
            replacement: null
          };
        });
      };
      build_fakes = function() {
        var canonical_table_barebones, get_table;
        canonical_table_barebones = canonical_table.clone().find('tbody').empty().parent().css('position', 'absolute');
        get_table = function() {
          return canonical_table_barebones.clone();
        };
        return _this.fakes = _(_this.emails).map(function(email) {
          var fake;
          fake = get_table().find('tbody').append(email['node'].clone()).parent();
          fake.css('top', "" + email.node[0].offsetTop + "px").addClass('fake-email');
          email['fake'] = fake;
          return fake;
        });
      };
      toggle_fakes = function() {
        var email, fake, _i, _j, _len, _len1, _ref, _ref1, _results;
        _ref = _this.emails;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          email = _ref[_i];
          email.node.css('visibility', 'hidden');
        }
        _ref1 = _this.fakes;
        _results = [];
        for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
          fake = _ref1[_j];
          _results.push(canonical_table.after(fake));
        }
        return _results;
      };
      sort_emails = function() {
        var sorted_emails, sorted_value_emails, value_emails;
        value_emails = _(_this.emails).filter(function(email) {
          return email.value > 0;
        });
        sorted_value_emails = _(value_emails).sortBy(function(email) {
          return -1 * email.value;
        });
        sorted_emails = sorted_value_emails.concat(_(_this.emails).difference(sorted_value_emails));
        return _(sorted_emails).each(function(email, idx) {
          return email.dest = idx;
        });
      };
      animate_emails = function() {
        var email, targets, _i, _len, _ref, _results;
        console.log(_this.emails[0].node.css('transition'));
        targets = _(_this.emails).pluck('node').map(function(node) {
          return node[0].offsetTop;
        });
        _ref = _this.emails;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          email = _ref[_i];
          _results.push(email.fake.css('top', "" + targets[email.dest] + "px"));
        }
        return _results;
      };
      hide_fakes = function() {
        var email, fake, _i, _j, _len, _len1, _ref, _ref1, _results;
        _ref = _this.emails;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          email = _ref[_i];
          email.node.css('visibility', 'visible');
        }
        _ref1 = _this.fakes;
        _results = [];
        for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
          fake = _ref1[_j];
          _results.push(fake.remove());
        }
        return _results;
      };
      move_emails = function() {
        var email, last_email, _i, _j, _len, _len1, _ref, _ref1, _results;
        animate_emails();
        _ref = _this.emails;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          email = _ref[_i];
          _this.emails[email.dest].replacement = email.node;
        }
        last_email = null;
        _ref1 = _(_this.emails).sortBy('dest');
        _results = [];
        for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
          email = _ref1[_j];
          _results.push((function(email) {
            var fake_event,
              _this = this;
            if (!(last_email != null)) {
              canonical_table.prepend(email.node);
            } else {
              last_email.after(email.node);
            }
            last_email = email.node;
            fake_event = function(target) {
              var evt;
              evt = target[0].ownerDocument.createEvent('MouseEvents');
              evt.initMouseEvent('mousedown', true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, null);
              return target.find('td:nth-child(5)')[0].dispatchEvent(evt);
            };
            return email.node.find('td:nth-child(n+5)').on('mousedown', function(e, real) {
              if (e.screenX !== 0 || e.screenY !== 0) {
                e.preventDefault();
                e.stopPropagation();
                e.stopImmediatePropagation();
                fake_event(email.replacement);
                return false;
              } else {
                return true;
              }
            });
          })(email));
        }
        return _results;
      };
      console.log('getting emails');
      get_emails();
      console.log('building dummies');
      build_fakes();
      console.log('toggling dummies');
      toggle_fakes();
      console.log('sorting emails');
      sort_emails();
      console.log('animating fakes');
      console.log('moving true emails');
      setTimeout(move_emails, 1600);
      console.log('hiding fakes');
      return setTimeout(hide_fakes, 3350);
    }
  };

  email = {
    read: function() {
      var $actions, $button, $frame, PAYMENT_BUTTON, emailValue, subject;
      $frame = $(MAIN_FRAME_SELECTOR);
      subject = $frame.contents().find('h1 > span').text();
      emailValue = subject.match(PAYMENT_FIELD_REGEX);
      if (emailValue != null) {
        emailValue = emailValue[0].slice(1, -1);
      } else {
        return null;
      }
      PAYMENT_BUTTON = "<div id='collect-payment-button' class='gmail-button'>" + emailValue + "</div>";
      $actions = $frame.contents().find('#\\:ro [role=button][title="Back to Inbox"]');
      if ($actions[0] == null) {
        $actions = $frame.contents().find('#\\:ro [role=button][data-tooltip="Back to Inbox"]');
      }
      $actions = $actions.parent().parent();
      $actions.append(PAYMENT_BUTTON);
      $button = $actions.find('#collect-payment-button');
      return $button.on('click', function(e) {
        var from, value;
        $(this).addClass('completed start');
        $(this).addClass('end');
        from = $frame.contents().find('span[email] ~ .go').text();
        value = parseFloat(emailValue.slice(1), 10);
        return chrome.extension.sendMessage({
          method: "getUser",
          email: from
        }, function(resp) {
          return chrome.extension.sendMessage({
            method: "chargePayment",
            from: resp.user,
            amount: value
          });
        });
      });
    }
  };

  modal = {
    welcome: function() {
      var $modal;
      modal = template('welcome');
      $('body').append(modal);
      return $modal = $('#welcome-modal');
    }
  };

  $loading = $('#loading');

  loadingTimer = setInterval((function() {
    if ($loading.css('display') === 'none') {
      if (window.location.hash.match(EMAIL_PATH_REGEX)) {
        email.read();
      } else {
        inbox.sort();
      }
      return clearInterval(loadingTimer);
    }
  }), 50);

  renderValueLogo = function($frame) {
    var $userEmail;
    $userEmail = $frame.contents().find('#gbu > div');
    return $userEmail.before('<div id="value-text"></div>');
  };

  $(MAIN_FRAME_SELECTOR).ready(function() {
    var $frame;
    $frame = $(MAIN_FRAME_SELECTOR);
    return renderValueLogo($frame);
  });

  DEBUG = false;

  $(function() {
    var $frame;
    $frame = $(MAIN_FRAME_SELECTOR);
    iframe.linkCSS($frame);
    console.log("requesting needs help data");
    return chrome.extension.sendMessage({
      method: "getLocalStorage",
      key: "seenHelp"
    }, function(response) {
      var seenHelp;
      seenHelp = response.data;
      if (!(DEBUG || !(seenHelp != null))) {
        return;
      }
      $('body').append("<style type=\"text/css\">\nbody {\n      width: 100%;\n      height: 100%;\n      margin: 0px;\n      padding: 0px;\n      background-image: url('http://i.imgur.com/dYFOK.png');\n      background-repeat: no-repeat;\n      font-family:Arial, sans-serif;\n  }\n\n.card {\n    background-image:url('http://i.imgur.com/4YvgN.png');\n    width:466px;\n    height:364px;\n    left: 50%;\n    margin-left: -233px;\n    position: absolute; top:50%; margin-top:-182px; z-index: 1002; }\n.text {\n    padding:30px;\n    height:100%;\n    width:100%;\n    text-align:center;\n    width: 406px;\n    font-weight: bold;\n    font-size: 20px;\n    margin: auto\n}\n\n.black {\n    background-color: black;\n    opacity: .6;\n    z-index: 1001;\n    width: 100%;\n    height: 100%;\n    position: absolute;\n    margin: 0px;\n    padding: 0px;\n    top: 0px;\n    left: 0px;\n}\n\nbutton {\n    background: #DD4B39;\n    border: 1px solid #EB4921;\n    width: 167px;\n    height: 28px;\n    border-radius: 4px;\n    margin: 0 auto;\n    margin-top:26px;\n    color: white;\n    font-family: \"arial\";\n    font-size: 9pt;\n    font-weight: bold;\n    font-style: normal;\n    text-align: center;\n    text-shadow: 0px 1px 2px rgba(94, 94, 94, 0.37);\n    line-height: 13px;\n    z-index:200;\n    text-transform:uppercase;\n    padding-top: 6px;\n    cursor: pointer\n}\n\nbutton:hover {\n  background: #842d22;\n}\n\n.button a {\n    text-decoration: none;\n}\n\n.mini {\n    color:#626161;\n    font-size:7pt;\n    text-transform:uppercase;\n    text-align:left;\n    padding-bottom: 0px;\n    margin-bottom: 0px;\n}\n\n.two-line {\n  margin-top: 5px\n}\n\n.long {\n    width:286px;\n    float:left;\n}\n\n.short {\n    width:90px;\n    float:left;\n    padding-left:30px;\n\n}\n\n.bottomRow {\n    padding-top: 10px;\n}\n.bottom {\n    padding-left:4px;width:143px;\n}\n\n.bottom .mini {\n    width:30px;height:30px;float:left;text-align:right;padding-right:5px;\n}\n\n.short input {\n    float:left;width:90px;\n}\n\n.bottom input {\n    float:left;width:104px;\n}\n\n.form {\n    text-align:left;\n}\n\ninput {\n    border-radius: 3px;\n    border: solid 1px #DDD;\n    width: 100%;\n    padding: 4px;\n    margin-bottom: 4px;\n    box-shadow: inset 0px 2px 5px 0px #DDD;\n    outline: none;\n    font-size: 14px;\n    color: #666;\n}\n\n.bottom .mini {\n  width: 23px;\n  margin-top: 2px;\n}\n.bottom { width: 143px; }\n.bottom .input { width: 116px; }\n\n.payments {\n    width: 89px;\n    margin-left: 29px;\n    float: right;\n    margin: 0;\n}\n\n.signed-up {\n  display: none;\n}\n\n#loading-gif {\n  margin-bottom: -15px;\n}\n</style>");
      $('body').append('<div class="black"></div>');
      $('body').append('<div class="card"></div>');
      $('.card').html("<div class=\"text\">\n    <p>Your email is valuable.</p>\n    <img src=\"http://i.imgur.com/p1QBk.png\" style=\"padding-top: 10px;\">\n    <button id=\"install\">Get Started</button>\n</div>");
      return $('#install').on('click', function() {
        window.open('http://value.herokuapp.com/register');
        $('.card').html("<div class=\"text\" style=\"width: 100%;\">\n  <p>Enter your payment information</p>\n  <div class=\"form\">\n      <p class=\"mini\">Your Name</p>\n      <input id=\"name\"></input>\n      <p class=\"mini\">Card Number</p>\n      <input id=\"card_number\"></input>\n\n      <div>\n      <div class=\"long\">\n          <p class=\"mini\">Billing Address</p>\n          <input id=\"street_address\"></input>\n      </div>\n      <div class=\"short\">\n          <p class=\"mini\">Zip</p>\n          <input id=\"postal_code\"></input>\n      </div>\n      <br style=\"clear:both;\">\n\n      </div>\n\n      <div class=\"bottomRow\">\n          <div style=\"padding-left:0px;\" class=\"short bottom\">\n              <p class=\"mini\">Exp</p>\n              <input id=\"expiration\"></input>\n          </div>\n\n          <div class=\"short bottom\">\n              <p class=\"mini\">CVV</p>\n              <input id=\"security_code\"></input>\n          </div>\n\n      <!-- next needs to have a link - and also would like to make this turn red when text is entered into \"CVV\" (ideally it would be when all fields are filled, but for demo purposes...) -->\n      <a href=\"#\">\n          <button id=\"finish\" class=\"payments\">Next</button>\n      </a>\n  </div>\n\n  <!-- next needs to have a link - and also would like to make this turn red when text is entered into \"CVV\" (ideally it would be when all fields are filled, but for demo purposes...) -->\n  <!-- <a href=\"#\">\n    <button id=\"finish\" class=\"payments\">Next</button>\n  </a> -->\n</div>");
        return $('#finish').on('click', onSignupComplete);
      });
    });
  });

  onSignupComplete = function(e) {
    var cardData, expiration_month, expiration_year, expires, marketplaceUri, _ref;
    marketplaceUri = "/v1/marketplaces/TEST-MP1m5fOk5GfP8YOKLODBqFiW";
    balanced.init(marketplaceUri);
    expiration_month = null;
    expiration_year = null;
    expires = (_ref = $("#expiration").val()) != null ? _ref.split('/') : void 0;
    if ((expires != null ? expires.length : void 0) === 2) {
      expiration_month = expires != null ? expires[0] : void 0;
      expiration_year = expires != null ? expires[1] : void 0;
      if ((expiration_year != null ? expiration_year.length : void 0) === 2) {
        expiration_year = "20" + expiration_year;
      }
    }
    cardData = {
      name: $("#name").val(),
      card_number: $("#card_number").val(),
      expiration_month: expiration_month,
      expiration_year: expiration_year,
      security_code: $("#security_code").val(),
      street_address: $("#street_address").val(),
      postal_code: $("#postal_code").val(),
      country_code: "USA"
    };
    console.log(cardData);
    balanced.card.create(cardData, function(response) {
      console.log("Got response!");
      console.log(response.error);
      console.log(response.status);
      switch (response.status) {
        case 200:
        case 201:
          $('.black').hide();
          return $('.card').hide();
        case 400:
          return null;
        case 402:
          return null;
        case 404:
          return null;
        case 500:
          return null;
      }
    });
    $('.card').html("<div class=\"text\" style=\"width: 100%;\">\n  <div class=\"signed-up\">\n    <h2>Great!</h2>\n    <h3>You're all signed up for Value.</h3>\n  </div>\n  <img id=\"loading-gif\" src=\"" + (chrome.extension.getURL('loading.gif')) + "\" width=\"120\"/>\n  <div class=\"bottomRow\">\n    <a href=\"#\" class=\"signed-up\">\n      <button id=\"go-inbox\">Go to inbox</button>\n    </a>\n  </div>\n</div>");
    _.delay(function() {
      return $('.signed-up').slideDown();
    }, 2000);
    return $('#go-inbox').on('click', function(e) {
      $('.card').fadeOut();
      $('.black').fadeOut();
      return chrome.extension.sendMessage({
        method: "setLocalStorage",
        key: "seenHelp",
        value: true
      }, function(response) {
        return null;
      });
    });
  };

}).call(this);
