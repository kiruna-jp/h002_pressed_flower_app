// api/generate.js
export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Credentials', true);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,POST');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version'
  );

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  try {
    const { imageBase64 } = req.body;

    if (!imageBase64) {
      return res.status(400).json({ error: 'Missing imageBase64 parameter' });
    }

    const token = process.env.REPLICATE_API_TOKEN;
    if (!token) {
      return res.status(500).json({ error: 'REPLICATE_API_TOKEN is not configured in Vercel' });
    }

    // 1. Replicateの /v1/files エンドポイントへ画像アップロード
    const buffer = Buffer.from(imageBase64, 'base64');
    const blob = new Blob([buffer], { type: 'image/jpeg' });
    const formData = new FormData();
    formData.append('content', blob, 'uploaded_flower.jpg');

    const uploadRes = await fetch('https://api.replicate.com/v1/files', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
      },
      body: formData,
    });

    const uploadData = await uploadRes.json();

    if (!uploadRes.ok) {
      return res.status(uploadRes.status).json({
        error: 'Failed to upload image to Replicate',
        detail: uploadData,
      });
    }

    const uploadedImageUrl = uploadData.urls.get;

    // 2. 画面から取得した正確なバージョンハッシュを使用
    const predictionRes = await fetch('https://api.replicate.com/v1/predictions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        version: '683d19dc312f7a9f0428b04429a9ccefd28dbf7785fef083ad5cf991b65f406f',
        input: {
          image: uploadedImageUrl,
          prompt: 'pressed flower style, botanical art, dried realistic flower petals, elegant vintage layout, high resolution, detailed texture',
          negative_prompt: 'ugly, blurry, low quality, distorted',
          prompt_strength: 0.45,
          num_inference_steps: 25,
        },
      }),
    });

    const predictionData = await predictionRes.json();

    if (!predictionRes.ok) {
      return res.status(predictionRes.status).json({
        error: 'Failed to create prediction',
        detail: predictionData,
      });
    }

    return res.status(200).json(predictionData);

  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
}