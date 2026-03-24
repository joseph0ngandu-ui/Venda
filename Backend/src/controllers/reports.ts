import { Response } from 'express';
import pool from '../config/db';
import { AuthRequest } from '../middleware/auth';

type TimeframeKey = 'week' | 'month' | 'year';

const timeframeConfig: Record<TimeframeKey, { intervalSql: string; bucketSql: string; labelSql: string }> = {
  week: {
    intervalSql: "NOW() - INTERVAL '6 days'",
    bucketSql: "date_trunc('day', created_at)",
    labelSql: "to_char(date_trunc('day', created_at), 'Dy')",
  },
  month: {
    intervalSql: "NOW() - INTERVAL '29 days'",
    bucketSql: "date_trunc('day', created_at)",
    labelSql: "to_char(date_trunc('day', created_at), 'DD Mon')",
  },
  year: {
    intervalSql: "NOW() - INTERVAL '11 months'",
    bucketSql: "date_trunc('month', created_at)",
    labelSql: "to_char(date_trunc('month', created_at), 'Mon')",
  },
};

const normalizeTimeframe = (value: unknown): TimeframeKey => {
  switch (value) {
    case 'month':
    case 'year':
      return value;
    default:
      return 'week';
  }
};

export const getReportsSummary = async (req: AuthRequest, res: Response) => {
  const merchantId = req.merchant?.id;

  if (!merchantId) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const timeframe = normalizeTimeframe(req.query.timeframe);
  const config = timeframeConfig[timeframe];

  try {
    const [summary, paymentBreakdown, topProducts, trend, recentSales] = await Promise.all([
      pool.query(
        `
          SELECT
            COALESCE(SUM(total_amount), 0) AS total_revenue,
            COUNT(*)::int AS sales_count,
            COALESCE(AVG(total_amount), 0) AS average_sale
          FROM sales
          WHERE merchant_id = $1
            AND created_at >= ${config.intervalSql}
        `,
        [merchantId]
      ),
      pool.query(
        `
          SELECT
            payment_method AS method,
            COALESCE(SUM(total_amount), 0) AS amount,
            COUNT(*)::int AS sales_count
          FROM sales
          WHERE merchant_id = $1
            AND created_at >= ${config.intervalSql}
          GROUP BY payment_method
          ORDER BY amount DESC
        `,
        [merchantId]
      ),
      pool.query(
        `
          SELECT
            p.id,
            COALESCE(p.name, 'Custom Item') AS name,
            COALESCE(SUM(li.quantity), 0) AS units_sold,
            COALESCE(SUM(li.final_price * li.quantity), 0) AS revenue
          FROM sale_line_items li
          LEFT JOIN products p ON p.id = li.product_id
          INNER JOIN sales s ON s.id = li.sale_id
          WHERE s.merchant_id = $1
            AND s.created_at >= ${config.intervalSql}
          GROUP BY p.id, p.name
          ORDER BY revenue DESC
          LIMIT 5
        `,
        [merchantId]
      ),
      pool.query(
        `
          SELECT
            ${config.labelSql} AS label,
            ${config.bucketSql} AS bucket,
            COALESCE(SUM(total_amount), 0) AS amount,
            COUNT(*)::int AS sales_count
          FROM sales
          WHERE merchant_id = $1
            AND created_at >= ${config.intervalSql}
          GROUP BY bucket, label
          ORDER BY bucket ASC
        `,
        [merchantId]
      ),
      pool.query(
        `
          SELECT
            s.id,
            s.reference,
            s.total_amount,
            s.payment_method,
            s.created_at,
            COALESCE(st.name, 'Staff') AS staff_name
          FROM sales s
          LEFT JOIN staff st ON st.id = s.staff_id
          WHERE s.merchant_id = $1
          ORDER BY s.created_at DESC
          LIMIT 5
        `,
        [merchantId]
      ),
    ]);

    const summaryRow = summary.rows[0] ?? {
      total_revenue: 0,
      sales_count: 0,
      average_sale: 0,
    };

    res.json({
      timeframe,
      generated_at: new Date().toISOString(),
      summary: {
        total_revenue: Number(summaryRow.total_revenue ?? 0),
        sales_count: Number(summaryRow.sales_count ?? 0),
        average_sale: Number(summaryRow.average_sale ?? 0),
      },
      payment_breakdown: paymentBreakdown.rows.map(row => ({
        method: row.method ?? 'Unknown',
        amount: Number(row.amount ?? 0),
        sales_count: Number(row.sales_count ?? 0),
      })),
      top_products: topProducts.rows.map(row => ({
        id: row.id,
        name: row.name,
        units_sold: Number(row.units_sold ?? 0),
        revenue: Number(row.revenue ?? 0),
      })),
      trend: trend.rows.map(row => ({
        label: String(row.label ?? '').trim(),
        amount: Number(row.amount ?? 0),
        sales_count: Number(row.sales_count ?? 0),
        bucket: row.bucket,
      })),
      recent_sales: recentSales.rows.map(row => ({
        id: row.id,
        reference: row.reference,
        total_amount: Number(row.total_amount ?? 0),
        payment_method: row.payment_method ?? 'Cash',
        staff_name: row.staff_name ?? 'Staff',
        created_at: row.created_at,
      })),
    });
  } catch (error) {
    console.error('Reports summary error:', error);
    res.status(500).json({ error: 'Unable to build reports summary' });
  }
};
