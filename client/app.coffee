'use strict'

console.log 'extension script loaded with jquery and underscore'

# check when 'compose' view is loaded
window.addEventListener 'hashchange', ->
  console.log window.location.hash
  if window.location.hash.match /compose/
    payment.renderButton()

MAIN_FRAME_SELECTOR = '#canvas_frame'

# all kinds of payment stuffs
payment =
  renderButton: ->

    # $actions = $('#:di')
    $actions = $(MAIN_FRAME_SELECTOR).contents()
                                     .find('div[role=navigation]')
                                     .last().children().first()

    # append '$' in compose view after email actions
    $actions.append('<div class="J-J5-Ji">$</div>').children('span').remove()

inbox =
  fakes: []
  emails: []
  sort: =>
    canonical_table = $('#canvas_frame').contents().find('table > colgroup').eq(1).parent()

    get_emails = =>
      $emails = canonical_table.find 'tr'
      @emails = _.map $emails, (email, i) ->
        subject = ($ email).find('td[role=link] div > span:first-child').text()
        value = subject.match /^\$[+-]?[0-9]{1,3}(?:,?[0-9]{3})*(?:\.[0-9]{2})?\$/
        if value?
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
  

$(MAIN_FRAME_SELECTOR).load ->
  console.log 'Inbox Loaded (Value)'
  inbox.sort()

# DOM ready
$ ->
  $(window).trigger 'hashchange'
