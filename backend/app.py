from flask import Flask, request, jsonify
import cv2
import numpy as np
import mediapipe as mp
import base64

app = Flask(__name__)

mp_pose = mp.solutions.pose
pose = mp_pose.Pose(static_image_mode=True, min_detection_confidence=0.5)

@app.route("/analyze_frame", methods=["POST"])
def analyze_frame():
    try:
        data = request.get_json()
        frame_data = data.get("frame")
        if not frame_data:
            return jsonify({"error": "No frame provided"}), 400

        # Decode the base64 image
        nparr = np.frombuffer(base64.b64decode(frame_data), np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if frame is None:
            return jsonify({"error": "Invalid image"}), 400

        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = pose.process(frame_rgb)

        if not results.pose_landmarks:
            return jsonify({"pose_detected": False, "message": "Could not detect a person"}), 200

        # Convert landmarks to (x, y, z) coordinates
        landmarks = [
            {"x": lm.x, "y": lm.y, "z": lm.z}
            for lm in results.pose_landmarks.landmark
        ]

        # ✅ Compatible with both old & new mediapipe versions
        connections = [
            [int(a) if hasattr(a, '__int__') else a.value,
             int(b) if hasattr(b, '__int__') else b.value]
            for (a, b) in mp_pose.POSE_CONNECTIONS
        ]

        return jsonify({
            "pose_detected": True,
            "landmarks": landmarks,
            "connections": connections
        })

    except Exception as e:
        print(e)
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=True)
