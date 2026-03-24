import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import apiRoutes from './routes/api';
import { initDb } from './config/db';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json({ limit: '10mb' })); // Support for large offline batches

app.use('/api/v1', apiRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'venda-api', timestamp: new Date().toISOString() });
});

const startServer = async () => {
  try {
    await initDb();

    app.listen(PORT, () => {
      console.log(`Venda Backend API running on port ${PORT}`);
    });
  } catch (error) {
    console.error('Failed to start Venda Backend API:', error);
    process.exit(1);
  }
};

void startServer();
