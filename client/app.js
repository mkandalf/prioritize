(function() {
  'use strict';
  var $loading, MAIN_FRAME_SELECTOR, PAYMENT_FIELD_REGEX, inbox, linkCSS, loadingTimer, modal, payment, template,
    _this = this;

  console.log('Value for Gmail extension script loaded');

  window.addEventListener('hashchange', function() {
    if (window.location.hash.match(/compose/)) return payment.renderButton();
  });

  MAIN_FRAME_SELECTOR = '#canvas_frame';

  PAYMENT_FIELD_REGEX = /^\[\$[+-]?[0-9]{1,3}(?:,?[0-9]{3})*(?:\.[0-9]{2})?\]/;

  template = function(domId) {
    return _.template(($("#" + domId).html() || "").trim());
  };

  linkCSS = function($frame) {
    return $frame.contents().find('head').append($('<link/>', {
      rel: 'stylesheet',
      type: 'text/css',
      href: chrome.extension.getURL('gmail_canvas.css')
    }).load(function() {
      return console.log('loaded css');
    }));
  };

  payment = {
    renderButton: function() {
      var $actions, $frame, $paybutton, $paymentField;
      $frame = $(MAIN_FRAME_SELECTOR);
      linkCSS($frame);
      $actions = $frame.contents().find('div[role=navigation]').last().children().first();
      $actions.children('span').remove();
      $actions.children().last().before('<div id="payment-button">$<input tabindex="2" type="text" name="pay_amount" /></div>');
      $paybutton = $actions.find('#payment-button');
      $paybutton.on('click', function(e) {
        return $(this).find('input').focus();
      });
      $paybutton.prevAll('[role=button]:contains("Send")').on('click', function(e) {
        var $to_emails, $value;
        $value = $paybutton.find('input').val();
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
      $paymentField = $actions.find('#payment-button input');
      $paymentField.on('click', function(e) {
        return $(this).focus();
      });
      return $paymentField.on('blur', _this.paymentFieldHandler);
    },
    hasCreatedPayment: false,
    paymentFieldHandler: function(e) {
      var $subject, amount;
      amount = $(e.currentTarget).val();
      console.log(amount);
      $subject = $(MAIN_FRAME_SELECTOR).contents().find('input[name=subject]');
      if ((amount * 1) === 0) {
        $subject.val($subject.val().replace(PAYMENT_FIELD_REGEX, "").trim());
        return payment.hasCreatedPayment = false;
      } else if (payment.hasCreatedPayment) {
        return $subject.val($subject.val().replace(PAYMENT_FIELD_REGEX, "[$" + amount + "]"));
      } else {
        payment.hasCreatedPayment = true;
        return $subject.val("[$" + amount + "] " + ($subject.val()));
      }
    }
  };

  inbox = {
    fakes: [],
    emails: [],
    sort: function() {
      var animate_emails, build_fakes, canonical_table, get_emails, hide_fakes, move_emails, sort_emails, toggle_fakes;
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
        var email, fake, _i, _j, _len, _len2, _ref, _ref2, _results;
        _ref = _this.emails;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          email = _ref[_i];
          email.node.css('visibility', 'hidden');
        }
        _ref2 = _this.fakes;
        _results = [];
        for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
          fake = _ref2[_j];
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
        var email, fake, _i, _j, _len, _len2, _ref, _ref2, _results;
        _ref = _this.emails;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          email = _ref[_i];
          email.node.css('visibility', 'visible');
        }
        _ref2 = _this.fakes;
        _results = [];
        for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
          fake = _ref2[_j];
          _results.push(fake.remove());
        }
        return _results;
      };
      move_emails = function() {
        var email, last_email, _i, _len, _ref, _results;
        last_email = null;
        _ref = _(_this.emails).sortBy('dest');
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          email = _ref[_i];
          if (!(last_email != null)) {
            canonical_table.prepend(email.node);
          } else {
            last_email.after(email.node);
          }
          last_email = email.node;
          _this.emails[email.dest].replacement = email.node;
          email.node.on('mousedown', function(e, real) {
            if (real !== "fo' real") {
              e.preventDefault();
              e.stopPropagation();
              e.stopImmediatePropagation();
              email.replacement.trigger('mousedown', "fo' real");
              return false;
            } else {
              return true;
            }
          });
          email.node.on('mouseup', function(e, real) {
            if (real !== "fo' real") {
              e.preventDefault();
              e.stopPropagation();
              e.stopImmediatePropagation();
              email.replacement.trigger('mouseup', "fo' real");
              return false;
            } else {
              return true;
            }
          });
          _results.push(email.node.on('click', function(e, real) {
            if (real !== "fo' real") {
              e.preventDefault();
              e.stopPropagation();
              e.stopImmediatePropagation();
              email.replacement.trigger('click', "fo' real");
              return false;
            } else {
              return true;
            }
          }));
        }
        return _results;
      };
      console.log('getting emails');
      get_emails();
      console.log('building dummies');
      build_fakes();
      console.log('toggling dummies');
      toggle_fakes();
      console.log('sorting');
      sort_emails();
      move_emails();
      setTimeout(animate_emails, 1000);
      return setTimeout(hide_fakes, 1650);
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
      inbox.sort();
      return clearInterval(loadingTimer);
    }
  }), 50);

  $(MAIN_FRAME_SELECTOR).load(function() {
    var $frame;
    $frame = $(MAIN_FRAME_SELECTOR);
    linkCSS($frame);
    console.log('main frame loaded');
    if (window.location.hash.match(/compose/)) return payment.renderButton();
  });

  $(function() {
    console.log("requesting needs help data");
    return chrome.extension.sendRequest({
      method: "getLocalStorage",
      key: "needsHelp"
    }, function(response) {
      var needsHelp;
      needsHelp = response.data;
      console.log("needsHelp: " + needsHelp);
      if (needsHelp) {
        $('body').append('<div style="height: 100%; width: 100%; z-index: 1001; position: absolute; top: 0px; left: 0px; opacity: 0.5; background: #666;"></div>');
        return $('body').append('<div style="height: 70%; width: 80%; z-index: 1002; position: absolute; top: 15%; left: 10%; background: white;"></div>');
      }
    });
  });

}).call(this);
