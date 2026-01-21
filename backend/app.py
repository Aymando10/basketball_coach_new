from flask import Flask, request, jsonify
import cv2
import numpy as np
import mediapipe as mp

app = Flask(__name__)

mp_pose = mp.solutions.pose
pose = mp_pose.Pose(
    static_image_mode=True,
    min_detection_confidence=0.5
)

POSE = mp_pose.PoseLandmark

LEFT = {
    "shoulder": POSE.LEFT_SHOULDER.value,
    "elbow": POSE.LEFT_ELBOW.value,
    "wrist": POSE.LEFT_WRIST.value,
    "hip": POSE.LEFT_HIP.value,
    "knee": POSE.LEFT_KNEE.value,
    "ankle": POSE.LEFT_ANKLE.value,
}

def calculate_angle(a, b, c):
    a = np.array(a)
    b = np.array(b)
    c = np.array(c)

    ba = a - b
    bc = c - b

    cosine_angle = np.dot(ba, bc) / (
        np.linalg.norm(ba) * np.linalg.norm(bc)
    )

    angle = np.degrees(np.arccos(np.clip(cosine_angle, -1.0, 1.0)))
    return angle

@app.route("/analyze_frame", methods=["POST"])
def analyze_frame():
    try:
        if 'frame' not in request.files:
            return jsonify({"error": "No frame provided"}), 400

        file = request.files['frame']
        npimg = np.frombuffer(file.read(), np.uint8)
        frame = cv2.imdecode(npimg, cv2.IMREAD_COLOR)

        if frame is None:
            return jsonify({"error": "Invalid image"}), 400

        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = pose.process(frame_rgb)

        if not results.pose_landmarks:
            return jsonify({"pose_detected": False}), 200

        lm = results.pose_landmarks.landmark

        # ---- Shot Metrics (MVP) ----
        knee_angle = calculate_angle(
            [lm[LEFT["hip"]].x, lm[LEFT["hip"]].y],
            [lm[LEFT["knee"]].x, lm[LEFT["knee"]].y],
            [lm[LEFT["ankle"]].x, lm[LEFT["ankle"]].y],
        )

        elbow_angle = calculate_angle(
            [lm[LEFT["shoulder"]].x, lm[LEFT["shoulder"]].y],
            [lm[LEFT["elbow"]].x, lm[LEFT["elbow"]].y],
            [lm[LEFT["wrist"]].x, lm[LEFT["wrist"]].y],
        )

        dx = lm[LEFT["shoulder"]].x - lm[LEFT["hip"]].x
        dy = lm[LEFT["hip"]].y - lm[LEFT["shoulder"]].y
        trunk_lean = abs(np.degrees(np.arctan2(dx, dy)))

        release_height = abs(
            lm[LEFT["wrist"]].y - lm[LEFT["hip"]].y
        )

        # ---- Naive MVP Score ----
        score = 100

        if knee_angle < 60 or knee_angle > 110:
            score -= 20

        if elbow_angle < 150:
            score -= 20

        if trunk_lean > 15:
            score -= 20

        if release_height < 0.2:
            score -= 20

        score = max(score, 0)

        landmarks = [
            {"x": p.x, "y": p.y, "z": p.z, "visibility": p.visibility}
            for p in lm
        ]

        connections = [
            [a.value, b.value] for a, b in mp_pose.POSE_CONNECTIONS
        ]

        return jsonify({
            "pose_detected": True,
            "landmarks": landmarks,
            "connections": connections,
            "metrics": {
                "knee_angle": round(knee_angle, 1),
                "elbow_angle": round(elbow_angle, 1),
                "trunk_lean": round(trunk_lean, 1),
                "release_height": round(release_height, 3),
            },
            "score": score
        })

    except Exception as e:
        print("ERROR:", e)
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=True)
