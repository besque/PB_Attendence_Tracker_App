from flask import Flask, jsonify, request
from dotenv import load_dotenv
from flask_cors import CORS
import json
import os
import smtplib
import qrcode
from io import BytesIO
import base64
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.image import MIMEImage
import uuid
import firebase_admin
from firebase_admin import credentials, firestore

app = Flask(__name__)
CORS(app)


cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)


db = firestore.client()


def load_participants_from_firebase(event_name=None):
    try:
        if event_name:
           
            participants_ref = db.collection('events').document(event_name).collection('participants')
            docs = participants_ref.stream()
            
            participants = []
            for doc in docs:
                data = doc.to_dict()
                
                participant = {
                    'participant_id': doc.id,
                    'participant_name': data.get('participant_name', ''),     # Fixed: was 'name'
                    'participant_email': data.get('participant_email', ''),   # Fixed: was 'email'
                    'event_name': event_name
                }
                participants.append(participant)
            
            return participants
        else:
           
            all_participants = []
            events_ref = db.collection('events')
            events = events_ref.stream()
            
            for event in events:
                event_name = event.id
                participants_ref = db.collection('events').document(event_name).collection('participants')
                docs = participants_ref.stream()
                
                for doc in docs:
                    data = doc.to_dict()
                    participant = {
                        'participant_id': doc.id,
                        'participant_name': data.get('participant_name', ''),   
                        'participant_email': data.get('participant_email', ''),   
                        'event_name': event_name
                    }
                    all_participants.append(participant)
            
            return all_participants
        
            
    except Exception as e:
        print(f"Error loading participants from Firebase: {e}")
        return []
            


def load_participants_from_json():
    try:
        with open('participants.json', 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"Error loading participants from JSON: {e}")
        return []


def generate_qr_code(participant_data):
    try:
        
        json_data = json.dumps(participant_data)
        
       
        encoded_data = base64.b64encode(json_data.encode('utf-8')).decode('utf-8')
        
        
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=10,
            border=4,
        )
        qr.add_data(encoded_data)
        qr.make(fit=True)
        
        
        img = qr.make_image(fill_color="black", back_color="white")
        
        
        buffer = BytesIO()
        img.save(buffer, format="PNG")
        buffer.seek(0)
        
        return buffer.getvalue()
    except Exception as e:
        print(f"Error generating QR code: {e}")
        return None

# email settings
EMAIL_SERVER = 'smtp.gmail.com'
EMAIL_PORT = 587
EMAIL_USER = os.getenv('EMAIL_USER')
EMAIL_PASSWORD = os.getenv('EMAIL_PASSWORD')
EMAIL_FROM = 'Blank <EMAIL_USER>'

def send_email(to_email, subject, body, participant_data=None):
    try:
        msg = MIMEMultipart('related')
        msg['Subject'] = subject
        msg['From'] = EMAIL_FROM
        msg['To'] = to_email

        qr_image = None
        html_body = f"""
        <html>
        <body>
            <p>Hello {participant_data.get('participant_name', '') if participant_data else ''},</p>
            <p>{body}</p>
        """

        if participant_data:
            qr_data = generate_qr_code(participant_data)
            if qr_data:
                qr_cid = str(uuid.uuid4())
                html_body += f"""
                <p>Here is your QR code for the event:</p>
                <img src="cid:{qr_cid}" width="300" height="300" />
                """
                qr_image = MIMEImage(qr_data)
                qr_image.add_header('Content-ID', f'<{qr_cid}>')

        html_body += """
            <p>Regards,<br>Event Team</p>
        </body>
        </html>
        """

        msg.attach(MIMEText(html_body, 'html'))

        if qr_image:
            msg.attach(qr_image)

        with smtplib.SMTP(EMAIL_SERVER, EMAIL_PORT) as server:
            server.starttls()
            server.login(EMAIL_USER, EMAIL_PASSWORD)
            server.send_message(msg)

        return True

    except Exception as e:
        print(f"Error sending email: {e}")
        return False


@app.route('/participants', methods=['GET'])
def get_participants():
    try:
        
        event_name = request.args.get('event', None)
        
        print(f"Fetching participants for event: {event_name}") 
        
       
        participants = load_participants_from_firebase(event_name)
        
        print(f"Found {len(participants)} participants")  
        
        return jsonify(participants)
        
    except Exception as e:
        print(f"Error in get_participants: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/events', methods=['GET'])
def get_events():
    
    try:
        events_ref = db.collection('events')
        events = events_ref.stream()
        
        event_list = []
        for event in events:
            event_list.append({
                'id': event.id,
                'name': event.id,
                'data': event.to_dict()
            })
        
        return jsonify(event_list)
        
    except Exception as e:
        print(f"Error fetching events: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/send-emails', methods=['POST'])
def send_emails_endpoint():
    try:
        data = request.json
        subject = data.get('subject', '')
        body = data.get('body', '')
        include_qr = data.get('include_qr', True)
        participants = data.get('participants', [])
        
        if not subject or not body or not participants:
            return jsonify({'success': False, 'message': 'Missing required fields'}), 400
        
        success_count = 0
        failure_count = 0
        
        for participant in participants:
            participant_data = participant if include_qr else None
            if send_email(participant['participant_email'], subject, body, participant_data):
                success_count += 1
            else:
                failure_count += 1
        
        return jsonify({
            'success': True,
            'message': f'Sent {success_count} emails, {failure_count} failed'
        })
    
    except Exception as e:
        return jsonify({'success': False, 'message': f'Error: {str(e)}'}), 500

@app.route('/test', methods=['GET'])
def test_endpoint():
    return jsonify({'message': 'Server is running!', 'status': 'OK'})

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)