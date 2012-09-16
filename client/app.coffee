'use strict'

console.log('Value for Gmail extension script loaded')

# the iframe that contains the main gmail app
MAIN_FRAME_SELECTOR = '#canvas_frame'
PAYMENT_FIELD_REGEX = /^\[\$[+-]?[0-9]{1,3}(?:,?[0-9]{3})*(?:\.[0-9]{2})?\]/
COMPOSE_PATH_REGEX  = /compose/
EMAIL_PATH_REGEX    = /#inbox\/[a-f|0-9]+$/

# check when 'compose' view is loaded
window.addEventListener 'hashchange', ->
  if window.location.hash.match COMPOSE_PATH_REGEX
    payment.renderButton()
  else if window.location.hash.match EMAIL_PATH_REGEX
    email.read()
  else if window.location.hash.match /^#inbox$/
    inbox.sort()

# helper method to generate underscore template functions given its dom ID
template = (domId) ->
  _.template ($("##{domId}").html() || "").trim()

iframe =
  isLinked: false
  linkCSS: ($frame) ->
    return null if iframe.isLinked
    # add a <link> tag to the iframe on the gmail app
    $frame.contents().find('head').append $('<link/>',
      rel: 'stylesheet'
      type: 'text/css'
      href: chrome.extension.getURL('gmail_canvas.css')
    ).load ->
      console.log 'loaded css'
      iframe.isLinked = true

# render arbitrary html in the gmail canvas action bar and return the action
# bar element
renderInActionBar = (el) ->
  $frame = $(MAIN_FRAME_SELECTOR)
  $actions = $frame.contents().find('#\\:ro > div:visible')
                   .find('[role=button]').first().parent()
  $actions.children('span').remove()
  # TODO: replace with handlebars template
  $actions.children().last().before(el)
  return $actions

# all kinds of payment stuffs
payment =
  renderButton: ->
    PAYMENT_BUTTON = '<div id="payment-button">$<input tabindex="2" type="text" name="pay_amount" /></div>'

    $frame = $(MAIN_FRAME_SELECTOR)
    $actions = $frame.contents().find('#\\:ro [role=button] > b').parent().parent()
    $actions.children('span').remove()
    $actions.children().last().before(PAYMENT_BUTTON)

    $paymentField = $actions.find('#payment-button input')
    # HACK: payment field isn't focusing on click by default.
    $paymentField.on 'click', (e) -> $(this).focus()
    $paymentField.on 'blur', (e) -> payment.amount = $(this).val()

    $sendEmail = $actions.children().first()

    # TODO: use better event
    $sendEmail.on 'mousedown', (e) ->
      $value = $paymentField.val()

      $subject = $frame.contents().find('input[name=subject]')
      $subject.val "[$#{$value}] #{$subject.val()}"

      $to_emails = $frame.contents().find('textarea[name="to"]').val()
      console.log $to_emails, $value
      _.each $to_emails.split(','), ($to) ->
          $to = $to.trim()
          chrome.extension.sendMessage {method: "getUser", email: $to}, ($data) ->
            console.log $data
            chrome.extension.sendMessage {method: "makePayment", to: $data.user, amount: $value}
    null

inbox =
  sorted: false
  fakes: []
  emails: []
  sort: =>
    if @sorted or not window.location.hash.match /^#inbox$/
      return

    @sorted = true

    canonical_table = $(MAIN_FRAME_SELECTOR).contents()
                                            .find('table > colgroup').eq(0)
                                            .parent()
    get_emails = =>
      $emails = canonical_table.find 'tr'
      @emails = _.map $emails, (email, i) ->
        subject = ($ email).find('td[role=link] div > span:first-child').text()
        value = subject.match PAYMENT_FIELD_REGEX
        if value?
          # strip off leading and trailing $ signs
          value = parseFloat value[0][2..-2]
        else
          value = 0
        node: $ email
        subject: subject
        value: value
        index: i
        dest: -1
        fake: null
        replacement: null

    build_fakes = =>
      canonical_table_barebones = canonical_table.clone()
                                    .find('tbody').empty().parent()
                                    .css('position', 'absolute')
      get_table = ->
        canonical_table_barebones.clone()

      @fakes = _(@emails).map (email) =>
        fake = get_table().find('tbody').append(email['node'].clone()).parent()
        fake.css('top', "#{email.node[0].offsetTop}px").addClass 'fake-email'
        email['fake'] = fake
        fake

    toggle_fakes = =>
      for email in @emails
        email.node.css 'visibility', 'hidden'
      for fake in @fakes
        canonical_table.after(fake)

    sort_emails = =>
      value_emails = _(@emails).filter (email) ->
        email.value > 0
      sorted_value_emails = _(value_emails).sortBy (email) ->
        -1 * email.value
      sorted_emails = sorted_value_emails.concat(_(@emails).difference sorted_value_emails)
      _(sorted_emails).each (email, idx) ->
        email.dest = idx

    animate_emails = =>
      console.log @emails[0].node.css 'transition'
      targets = _(@emails).pluck('node').map (node) ->
        node[0].offsetTop
      for email in @emails
        email.fake.css 'top', "#{targets[email.dest]}px"

    hide_fakes = =>
      for email in @emails
        email.node.css 'visibility', 'visible'
      for fake in @fakes
        fake.remove()

    move_emails = =>
      animate_emails()

      for email in @emails
        @emails[email.dest].replacement = email.node

      last_email = null
      for email in _(@emails).sortBy 'dest' then do (email) ->
        if not last_email?
          canonical_table.prepend email.node
        else
          last_email.after email.node
        last_email = email.node

        # We need to fix clicks, because google is stupid.
        # First, set the replacement nodes so we can find them later to simulate
        # clicks.
        # Then intercept and redirect the clicks
        # This method dispatches a fake mouse click on an jquery node
        fake_event = (target) ->
          evt = target[0].ownerDocument.createEvent 'MouseEvents'
          evt.initMouseEvent 'mousedown', true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, null
          target.find('td:nth-child(5)')[0].dispatchEvent evt
        email.node.find('td:nth-child(n+5)').on 'mousedown', (e, real) =>
          if e.screenX != 0 or e.screenY != 0
            e.preventDefault()
            e.stopPropagation()
            e.stopImmediatePropagation()
            fake_event email.replacement
            false
          else
            true

    console.log 'getting emails'
    get_emails()
    console.log 'building dummies'
    build_fakes()
    console.log 'toggling dummies'
    toggle_fakes()
    console.log 'sorting emails'
    sort_emails()
    console.log 'animating fakes'
    console.log 'moving true emails'
    setTimeout move_emails, 1600
    console.log 'hiding fakes'
    setTimeout hide_fakes, 3350

email =
  read: ->
    $frame = $(MAIN_FRAME_SELECTOR)
    subject = $frame.contents().find('h1 > span').text()
    emailValue = subject.match PAYMENT_FIELD_REGEX
    if emailValue?
      emailValue = emailValue[0][1..-2]
    else
      return null

    PAYMENT_BUTTON = "<div id='collect-payment-button' class='gmail-button'>#{emailValue}</div>"

    $actions = $frame.contents().find('#\\:ro [role=button][title="Back to Inbox"]')
    unless $actions[0]?
      $actions = $frame.contents().find('#\\:ro [role=button][data-tooltip="Back to Inbox"]')
    $actions = $actions.parent().parent()

    $actions.append(PAYMENT_BUTTON)
    $button = $actions.find('#collect-payment-button')

    $button.on 'click', (e) ->
      $(this).addClass 'completed start'
      $(this).addClass 'end'

      # ajax call to our API to charge payment
      from = $frame.contents().find('span[email] ~ .go').text()
      value = parseFloat emailValue[1..], 10

      chrome.extension.sendMessage
        method: "getUser"
        email: from
      , (resp) ->
          chrome.extension.sendMessage
            method: "chargePayment"
            from: resp.user
            amount: value

modal =
  welcome: ->
    modal = template 'welcome'
    $('body').append(modal)
    $modal = $('#welcome-modal')

$loading = $('#loading')

loadingTimer = setInterval (->
  if $loading.css('display') == 'none'
    if window.location.hash.match EMAIL_PATH_REGEX
      email.read()
    else
      inbox.sort()
    clearInterval loadingTimer)
  , 50

renderValueLogo = ($frame) ->
  $userEmail = $frame.contents().find('#gbu > div')
  $userEmail.before '<div id="value-text"></div>'

$(MAIN_FRAME_SELECTOR).ready ->
  $frame = $(MAIN_FRAME_SELECTOR)
  renderValueLogo($frame)


DEBUG = false


## DOM ready
$ ->
  $frame = $(MAIN_FRAME_SELECTOR)
  iframe.linkCSS($frame)

  console.log "requesting needs help data"
  chrome.extension.sendMessage {
    method: "getLocalStorage"
  , key: "seenHelp"
  }, (response) ->
    seenHelp = response.data
    return unless DEBUG or not seenHelp?
    # Apply black screen on top of gmail
    $('body').append """
    <style type="text/css">
    body {
          width: 100%;
          height: 100%;
          margin: 0px;
          padding: 0px;
          background-image: url('http://i.imgur.com/dYFOK.png');
          background-repeat: no-repeat;
          font-family:Arial, sans-serif;
      }

    .card {
        background-image:url('http://i.imgur.com/4YvgN.png');
        width:466px;
        height:364px;
        left: 50%;
        margin-left: -233px;
        position: absolute; top:50%; margin-top:-182px; z-index: 1002; }
    .text {
        padding:30px;
        height:100%;
        width:100%;
        text-align:center;
        width: 406px;
        font-weight: bold;
        font-size: 20px;
        margin: auto
    }

    .black {
        background-color: black;
        opacity: .6;
        z-index: 1001;
        width: 100%;
        height: 100%;
        position: absolute;
        margin: 0px;
        padding: 0px;
        top: 0px;
        left: 0px;
    }

    button {
        background: #DD4B39;
        border: 1px solid #EB4921;
        width: 167px;
        height: 28px;
        border-radius: 4px;
        margin: 0 auto;
        margin-top:26px;
        color: white;
        font-family: "arial";
        font-size: 9pt;
        font-weight: bold;
        font-style: normal;
        text-align: center;
        text-shadow: 0px 1px 2px rgba(94, 94, 94, 0.37);
        line-height: 13px;
        z-index:200;
        text-transform:uppercase;
        padding-top: 6px;
        cursor: pointer
    }

    button:hover {
      background: #842d22;
    }

    .button a {
        text-decoration: none;
    }

    .mini {
        color:#626161;
        font-size:7pt;
        text-transform:uppercase;
        text-align:left;
        padding-bottom: 0px;
        margin-bottom: 0px;
    }

    .two-line {
      margin-top: 5px
    }

    .long {
        width:286px;
        float:left;
    }

    .short {
        width:90px;
        float:left;
        padding-left:30px;

    }

    .bottomRow {
        padding-top: 10px;
    }
    .bottom {
        padding-left:4px;width:143px;
    }

    .bottom .mini {
        width:30px;height:30px;float:left;text-align:right;padding-right:5px;
    }

    .short input {
        float:left;width:90px;
    }

    .bottom input {
        float:left;width:104px;
    }

    .form {
        text-align:left;
    }

    input {
        border-radius: 3px;
        border: solid 1px #DDD;
        width: 100%;
        padding: 4px;
        margin-bottom: 4px;
        box-shadow: inset 0px 2px 5px 0px #DDD;
        outline: none;
        font-size: 14px;
        color: #666;
    }

    .bottom .mini {
      width: 23px;
      margin-top: 2px;
    }
    .bottom { width: 143px; }
    .bottom .input { width: 116px; }

    .payments {
        width: 89px;
        margin-left: 29px;
        float: right;
        margin: 0;
    }

    #loading-gif { margin-bottom: -15px; }
    </style>
    """
    $('body').append('<div class="black"></div>')
    # Main content for body
    $('body').append('<div class="card"></div>')
    $('.card').html """
      <div class="text">
          <p>Your email is valuable.</p>
          <img src="http://i.imgur.com/p1QBk.png" style="padding-top: 10px;">
          <button id="install">Get Started</button>
      </div>
      """
    $('#install').on 'click', ->
        window.open 'http://value.herokuapp.com/register'
        $('.card').html """
          <div class="text" style="width: 100%;">
            <p>Enter your payment information</p>
            <div class="form">
                <p class="mini">Your Name</p>
                <input id="name"></input>
                <p class="mini">Card Number</p>
                <input id="card_number"></input>

                <div>
                <div class="long">
                    <p class="mini">Billing Address</p>
                    <input id="street_address"></input>
                </div>
                <div class="short">
                    <p class="mini">Zip</p>
                    <input id="postal_code"></input>
                </div>
                <br style="clear:both;">

                </div>

                <div class="bottomRow">
                    <div style="padding-left:0px;" class="short bottom">
                        <p class="mini">Exp</p>
                        <input id="expiration"></input>
                    </div>

                    <div class="short bottom">
                        <p class="mini">CVV</p>
                        <input id="security_code"></input>
                    </div>

                <!-- next needs to have a link - and also would like to make this turn red when text is entered into "CVV" (ideally it would be when all fields are filled, but for demo purposes...) -->
                <a href="#">
                    <button id="finish" class="payments">Next</button>
                </a>
            </div>

            <!-- next needs to have a link - and also would like to make this turn red when text is entered into "CVV" (ideally it would be when all fields are filled, but for demo purposes...) -->
            <!-- <a href="#">
              <button id="finish" class="payments">Next</button>
            </a> -->
          </div>
        """
        $('#finish').on 'click', onSignupComplete

onSignupComplete = (e) ->
    marketplaceUri = "/v1/marketplaces/TEST-MP1m5fOk5GfP8YOKLODBqFiW"
    balanced.init(marketplaceUri);
    expiration_month = null
    expiration_year = null
    # 'valid-thru' should be of form 1/2000 or 1/00
    expires = $("#expiration").val()?.split('/')
    if expires?.length == 2
        expiration_month = expires?[0]
        expiration_year = expires?[1]
        if expiration_year?.length == 2
            # assume it's 20??
            expiration_year = "20" + expiration_year
    cardData =
        name: $("#name").val()
        card_number: $("#card_number").val()
        expiration_month: expiration_month
        expiration_year: expiration_year
        security_code: $("#security_code").val()
        street_address: $("#street_address").val()
        postal_code: $("#postal_code").val()
        country_code: "USA"
    console.log cardData
    balanced.card.create cardData, (response) ->
        console.log "Got response!"
        console.log response.error
        console.log response.status
        switch response.status
            when 200, 201
                alert "OK!"
                $('.black').hide()
                $('.card').hide()
                chrome.extension.sendMessage {
                  method: "setLocalStorage"
                , key: "seenHelp"
                , value: true
                }, (response) ->
                    null
            when 400
                # missing field
                alert "Missing field"
                console.log
                null
            when 402
                # unauthorized
                alert "We couldn't authorize the buyer's credit card"
                null
            when 404
                alert "Marketplace uri is incorrect"
            when 500
                alert "Something bad happened please retry"
    $('.card').html """
      <div class="text" style="width: 100%;">
        <h2>Great!</h2>
        <h3>You're all signed up for Value.</h3>
        <img id="loading-gif" src="#{chrome.extension.getURL('loading.gif')}" width="120"/>
        <div class="bottomRow">
          <a href="#">
            <button id="go-inbox">Go to inbox</button>
          </a>
        </div>
      </div>
    """
    $('#go-inbox').on 'click', (e) ->
      $('.card').fadeOut();
      $('.black').fadeOut();
