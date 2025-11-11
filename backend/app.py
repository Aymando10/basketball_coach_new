from flask import Flask, request, jsonify
import cv2
import mediapipe as mp
import numpy as np

app = Flask(__name__)
mp_pose = mp.solutions.pose

pose = mp_pose.Pose(
    static_image_mode=False,
    model_complexity=1,
    enable_segmentation=False,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
)

@app.route('/analyze_frame', methods=['POST'])
def analyze_frame():
    file = request.files.get('frame')
    if not file:
        return jsonify({'error': 'No frame uploaded'}), 400

    file_bytes = np.frombuffer(file.read(), np.uint8)
    image = cv2.imdecode(file_bytes, cv2.IMREAD_COLOR)
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

    results = pose.process(image_rgb)

    if not results.pose_landmarks:
        return jsonify({'detected': False})

    landmarks = [
        {'x': lm.x, 'y': lm.y, 'z': lm.z}
        for lm in results.pose_landmarks.landmark[:5]
    ]

    return jsonify({'detected': True, 'landmarks': landmarks})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)
