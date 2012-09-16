'use strict'

console.log('Value for Gmail extension script loaded')

# check when 'compose' view is loaded
window.addEventListener 'hashchange', ->
  if window.location.hash.match /compose/
    payment.renderButton()

# the iframe that contains the main gmail app
MAIN_FRAME_SELECTOR = '#canvas_frame'
PAYMENT_FIELD_REGEX = /^\[\$[+-]?[0-9]{1,3}(?:,?[0-9]{3})*(?:\.[0-9]{2})?\]/

template = (domId) ->
  _.template ($("##{domId}").html() || "").trim()

linkCSS = ($frame) ->
  $frame.contents().find('head').append $('<link/>',
    rel: 'stylesheet'
    type: 'text/css'
    href: chrome.extension.getURL('gmail_canvas.css')
  ).load ->
    console.log 'loaded css'

# all kinds of payment stuffs
payment =
  renderButton: =>
    $frame = $(MAIN_FRAME_SELECTOR)
    linkCSS($frame)

    $actions = $frame.contents().find('div[role=navigation]').last()
                     .children().first()

    $actions.children('span').remove()
    # append '$' in compose view after email actions
    # TODO: replace with handlebars template
    $actions.children().last().before(
      '<div id="payment-button">$<input tabindex="2" type="text" name="pay_amount" /></div>')

    $paymentButton = $actions.find('#payment-button')
    # HACK: payment field isn't focusing on click by default.
    $paymentButton.click (e) ->
      $(this).find('input').focus()
    $paymentButton.find('input').blur payment.paymentFieldHandler


  hasCreatedPayment: false

  paymentFieldHandler: (e) =>
    amount = $(e.currentTarget).val()
    console.log amount

    $subject = $(MAIN_FRAME_SELECTOR).contents().find('input[name=subject]')
    if ((amount * 1) == 0) # Coerce to a number
      # Clear the subj amount if The field is empty or a zero value
      $subject.val($subject.val().replace(PAYMENT_FIELD_REGEX, "").trim())
      payment.hasCreatedPayment = false
    else if payment.hasCreatedPayment
      $subject.val($subject.val().replace(PAYMENT_FIELD_REGEX, "[$#{amount}]"))
    else
      payment.hasCreatedPayment = true
      $subject.val "[$#{amount}] #{$subject.val()}"


inbox =
  fakes: []
  emails: []
  sort: =>
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
      last_email = null
      for email in _(@emails).sortBy 'dest'
        if not last_email?
          canonical_table.prepend email.node
        else
          last_email.after email.node
        last_email = email.node

        # We need to fix clicks, because google is stupid.
        # First, set the replacement nodes so we can find them later to simulate
        # clicks.
        @emails[email.dest].replacement = email.node
        # Then intercept and redirect the clicks
        email.node.on 'mousedown', (e, real) ->
          if real != "fo' real"
            e.preventDefault()
            e.stopPropagation()
            e.stopImmediatePropagation()
            email.replacement.trigger 'mousedown', "fo' real"
            false
          else
            true
        email.node.on 'mouseup', (e, real) ->
          if real != "fo' real"
            e.preventDefault()
            e.stopPropagation()
            e.stopImmediatePropagation()
            email.replacement.trigger 'mouseup', "fo' real"
            false
          else
            true
        email.node.on 'click', (e, real) ->
          if real != "fo' real"
            e.preventDefault()
            e.stopPropagation()
            e.stopImmediatePropagation()
            email.replacement.trigger 'click', "fo' real"
            false
          else
            true
        
    

    console.log 'getting emails'
    get_emails()
    console.log 'building dummies'
    build_fakes()
    console.log 'toggling dummies'
    toggle_fakes()
    console.log 'sorting'
    sort_emails()
    move_emails()
    setTimeout animate_emails, 1000
    setTimeout hide_fakes, 1650
    #animate_emails()
    #hide_fakes()

modal =
  welcome: ->
    modal = template 'welcome'
    $('body').append(modal)
    $modal = $('#welcome-modal')

done_loading = ->
  $(document.body).find('#loading').css('display') == 'none'

timer = setInterval (->
  if done_loading()
    inbox.sort()
    clearInterval timer)
  , 50

$(MAIN_FRAME_SELECTOR).load ->
  $frame = $(MAIN_FRAME_SELECTOR)
  linkCSS($frame)

  console.log 'main frame loaded'

  if window.location.hash.match /compose/
    payment.renderButton()


# DOM ready
#$ ->
    #console.log "requesting needs help data"
    #chrome.extension.sendRequest {method: "getLocalStorage", key: "needsHelp"}, (response) ->
        #needsHelp =  response.data
        #console.log "needsHelp:", needsHelp
        #if needsHelp
            ## alert "It looks like you need help"
            ## Apply black screen on top of gmail
            #$('body').append('<div style="height: 100%; width: 100%; z-index: 1001; position: absolute; top: 0px; left: 0px; opacity: 0.5; background: #666;"></div>')
            ## Main body for content
            #$('body').append('<div style="height: 70%; width: 80%; z-index: 1002; position: absolute; top: 15%; left: 10%; background: white;"></div>')
