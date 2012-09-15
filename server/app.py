import os

#from flask_oauth import OAuth
from flask.ext.sqlalchemy import SQLAlchemy
from sqlalchemy.ext.declarative import DeclarativeMeta
from flask.ext.googleauth import GoogleAuth

from sqlalchemy import and_

from flask import Flask, g, session, abort, request, redirect, render_template, Response
app = Flask(__name__)
app.config.from_object(__name__)

db = SQLAlchemy(app)

# If we are on heroku, grab the database url from the environment
try:
    app.config['SQLALCHEMY_DATABASE_URI'] = os.environ['DATABASE_URL']
except KeyError:
    app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql+psycopg2://value:value@localhost/priority'

app.secret_key = 'wtfwtfwtf'


class User(db.Model):
    id = db.Column(db.Integer, primary_key=True, nullable=False)

    name = db.Column(db.String(32), nullable=True, default='')
    google_id = db.Column(db.String(255), nullable=True)
    google_token = db.Column(db.String(255), nullable=True)
    openid = db.Column(db.String(255), nullable=False)

    payments_sent = db.relation('Payment', backref='sender', primaryjoin="Payment.sender_id==User.id")
    payments_received = db.relation('Payment', backref='receiver', primaryjoin="Payment.receiver_id==User.id")


class Payment(db.Model):
    id = db.Column(db.Integer, primary_key=True, nullable=False)

    amount = db.Column(db.Numeric(precision=10, scale=2), nullable=False)
    executed = db.Column(db.Boolean, nullable=False, default=False)

    sender_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    receiver_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)

# Setup Google Auth
class ValueGoogleAuth(GoogleAuth):
    def _on_auth(self, user):
        if not user:
            # Google auth failed.
            abort(403)
        else:
            if not User.query.filter_by(openid=user["identity"]).first():
                db.session.add(User(openid=user["identity"]))
                db.session.commit()
        # This is redundant, but I fear the entire library will break if I kill the first line.
        session['openid'] = user
        session['user'] = User.query.filter_by(openid=user["identity"]).first()
        return redirect(request.args.get('next', None) or request.referrer or '/')

auth = ValueGoogleAuth(app)

@app.route('/users/<receiver_id>/payments/new', methods=['POST'])
@auth.required
def make_payment(receiver_id):
    """Make a new payment"""
    amount = request.form.get('amount')
    payment = Payment(sender_id=session['user'].id, receiver_id=receiver_id, amount=amount)
    db.session.add(payment)
    db.session.commit()
    return Response(response=None)

@app.route('/payments/<amount>/execute', methods=['POST'])
@auth.required
def execute_payment(amount):
    """Execute a payment"""
    payment = Payment.query.filter(and_(Payment.receiver_id==session['user'].id, Payment.amount==amount, Payment.executed==False)).first()
    if payment:
        payment.executed = True
        db.session.commit()
    return Response(response=None)

if __name__ == '__main__':
    # Bind to PORT if defined, otherwise default to 5000.
    db.create_all()
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True)


###
# Models
###
