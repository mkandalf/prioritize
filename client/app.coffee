'use strict'

console.log('Value for Gmail extension script loaded')

# check when 'compose' view is loaded
window.addEventListener 'hashchange', ->
  if window.location.hash.match /compose/
    payment.renderButton()
  else if window.location.hash.match /^#inbox$/
    inbox.sort()

# the iframe that contains the main gmail app
MAIN_FRAME_SELECTOR = '#canvas_frame'
PAYMENT_FIELD_REGEX = /^\[\$[+-]?[0-9]{1,3}(?:,?[0-9]{3})*(?:\.[0-9]{2})?\]/

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
  iframe.linkCSS($frame)

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

    $actions = renderInActionBar(PAYMENT_BUTTON)
    $paymentField = $actions.find('#payment-button input')

    # HACK: payment field isn't focusing on click by default.
    $paymentField.on 'click', (e) -> $(this).focus()
    $paymentField.on 'blur', (e) -> payment.amount = $(this).val()

    $sendEmail = $actions.children().first()
    $sendEmail.on 'mousedown', @attachPaymentOnSubmit

    $paybutton = $actions.find('#payment-button')
    $paybutton.prevAll('[role=button]:contains("Send")').on 'click', (e) ->
      $value = $paybutton.find('input').val()
      $to_emails = $frame.contents().find('textarea[name="to"]').val()
      console.log $to_emails, $value
      _.each $to_emails.split(','), ($to) ->
          $to = $to.trim()
          chrome.extension.sendMessage {method: "getUser", email: $to}, ($data) ->
            console.log $data
            chrome.extension.sendMessage {method: "makePayment", to: $data.user, amount: $value}
    null

  attachPaymentOnSubmit: (e) =>
    # Prepend payment amount in email subject just before sending
    $subject = $(MAIN_FRAME_SELECTOR).contents().find('input[name=subject]')
    $subject.val "[$#{payment.amount}] #{$subject.val()}"
    # TODO: hit our app's API to save this amount to the database
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
    PAYMENT_BUTTON = "<div id='collect-payment-button'>$#{emailValue}</div>"

    $actions = renderInActionBar(PAYMENT_BUTTON)
    $button = $actions.find('#collect-payment-button')

    $button.on 'click', (e) -> $(this).addClass('completed')
    # TODO: fix this function to render the payment button correctly

modal =
  welcome: ->
    modal = template 'welcome'
    $('body').append(modal)
    $modal = $('#welcome-modal')

$loading = $('#loading')

loadingTimer = setInterval (->
  if $loading.css('display') == 'none'
    inbox.sort()
    clearInterval loadingTimer)
  , 50

$(MAIN_FRAME_SELECTOR).load ->
  $frame = $(MAIN_FRAME_SELECTOR)
  iframe.linkCSS($frame)

  console.log 'main frame loaded'

  if window.location.hash.match /compose/
    payment.renderButton()
  else if window.location.hash.match /#inbox\/[a-f|0-9]+$/
    email.read()


## DOM ready
$ ->
  console.log "requesting needs help data"
  chrome.extension.sendMessage {
    method: "getLocalStorage"
  , key: "needsHelp"
  }, (response) ->
    console.log response
    needsHelp = response.data
    console.log "needsHelp: #{needsHelp}"
    if needsHelp
      # Apply black screen on top of gmail
      # TODO: swap these out for underscore templates
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
            position: absolute;
            top:50%;
            margin-top:-182px;
            z-index: 1002;
        }

        .text {
            padding:30px;
            height:100%;
            width:100%;
            text-align:center;
            width: 406px;
            font-weight: bold;
            font-size: 20px;
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
            border-color: #CDCDCD;
            border-width: 1px;
            width: 100%;
            height: 23px;
            margin-top: 3px;
            margin-bottom:14px;
            box-shadow: 0px;
            box-shadow: inset 2px 2px 2px 0px #DDD;
        }

        .payments {
            width: 89px;
            margin-left: 29px;
            float: right;
            margin: 0;
        }
      </style>
      """
      $('body').append('<div class="black"></div>')
      # Main body for content
      $('body').append('<div class="card"></div>')
      $('.card').html """
      <div class="text">
          <p>Your email is valuable.</p>
          <img src="http://i.imgur.com/p1QBk.png" style="padding-top: 10px;">
          <button id="install">Install</button>
      </div>
      """
      $('#install').on 'click', ->
          window.open 'http://0.0.0.0:5000/register'
          $('.card').html """
          <div class="text" style="width: 100%;">
                <p>Enter your payment information</p>
                <div class="form">
                    <p class="mini">Your Name</p>
                    <input></input>
                    <p class="mini">Card Number</p>
                    <input></input>
                    
                    <div>
                    <div class="long">
                        <p class="mini">Billing Address</p>
                        <input></input>
                    </div>
                    <div class="short">
                        <p class="mini">Zip</p>
                        <input></input>
                    </div>
                    <br style="clear:both;">
                    
                    </div>
                    
                    <div class="bottomRow">
                        <div style="padding-left:0px;" class="short bottom">
                            <p class="mini">Valid thru</p>
                            <input></input>
                        </div>
                
                        <div class="short bottom">
                            <p class="mini">CVV</p>
                            <input></input>
                        </div>
                
                    <!-- next needs to have a link - and also would like to make this turn red when text is entered into "CVV" (ideally it would be when all fields are filled, but for demo purposes...) -->
                    <a href="next.html">
                        <button class="payments">Next</button>
                    </a>
                </div>

            </div>
          """


