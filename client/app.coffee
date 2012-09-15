'use strict'

console.log('Value for Gmail extension script loaded')

# check when 'compose' view is loaded
window.addEventListener 'hashchange', ->
  if window.location.hash.match /compose/
    payment.renderButton()

# the iframe that contains the main gmail app
MAIN_FRAME_SELECTOR = '#canvas_frame'
PAYMENT_FIELD_REGEX = /^\$[+-]?[0-9]{1,3}(?:,?[0-9]{3})*(?:\.[0-9]{2})?\$/

template = (domId) ->
  _.template ($("##{domId}").html() || "").trim()

linkCSS = ($frame) ->
  $frame.contents().find('head').append $('<link/>',
    rel: 'stylesheet'
    type: 'text/css'
    href: chrome.extension.getURL('gmail_canvas.css')
  )

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
      '<div id="payment-button">$<input type="text" name="pay_amount" /></div>')

    $actions.find('#payment-button').on 'click', (e) ->
      $(this).find('input').focus()

  hasCreatedPayment: false

  paymentFieldHandler: (e) =>
    amount = $(e.currentTarget).val()
    console.log amount

    $subject = $(MAIN_FRAME_SELECTOR).contents().find('input[name=subject]')

    if hasCreatedPayment
      $subject.val($subject.val().replace(PAYMENT_FIELD_REGEX, "$#{amount}$"))
    else
      hasCreatedPayment = true
      $subject.val "$#{amount}$ #{$subject.val()}"


inbox =
  fakes: []
  emails: []
  sort: =>
    canonical_table = $(MAIN_FRAME_SELECTOR).contents()
                                            .find('table > colgroup').eq(1)
                                            .parent()
    get_emails = =>
      $emails = canonical_table.find 'tr'
      @emails = _.map $emails, (email, i) ->
        subject = ($ email).find('td[role=link] div > span:first-child').text()
        value = subject.match PAYMENT_FIELD_REGEX
        if value?
          # strip off leading and trailing $ signs
          value = parseFloat value[0][1..-2]
        else
          value = 0
        node: $ email
        subject: subject
        value: value
        index: i
        dest: -1
        fake: null

    build_fakes = =>
      get_table = ->
        canonical_table.clone()
                        .find('tbody').empty().parent()
                        .css('position', 'absolute')

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
        -1 * value
      sorted_emails = sorted_value_emails.concat(_(@emails).without sorted_value_emails)
      _(sorted_emails).each (email, idx) ->
        email.index = idx

    console.log 'getting emails'
    get_emails()
    console.log 'building dummies'
    build_fakes()
    console.log 'toggling dummies'
    toggle_fakes()
    console.log 'sorting'

modal =
  welcome: ->
    modal = template 'welcome'
    $('body').append(modal)
    $modal = $('#welcome-modal')

  
$(MAIN_FRAME_SELECTOR).load ->
  console.log 'main frame loaded'

  if window.location.hash.match /inbox/
    inbox.sort()
  else if window.location.hash.match /compose/
    payment.renderButton()

# DOM ready
$ ->
  $
