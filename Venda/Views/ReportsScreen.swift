import SwiftUI

struct ReportsScreen: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTimeframe = 0
    
    // Mock Data for the chart
    let weeklyData: [ChartDataPoint] = [
        ChartDataPoint(label: "M", value: 1200),
        ChartDataPoint(label: "T", value: 450),
        ChartDataPoint(label: "W", value: 2800),
        ChartDataPoint(label: "T", value: 1800),
        ChartDataPoint(label: "F", value: 3400),
        ChartDataPoint(label: "S", value: 4200),
        ChartDataPoint(label: "S", value: 1500)
    ]
    
    var maxValue: Decimal {
        weeklyData.map { $0.value }.max() ?? 1000
    }
    
    var body: some View {
        ZStack {
            Color.vendaSand
                .ignoresSafeArea()
                
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.vendaInk)
                            .frame(width: 40, height: 40)
                            .background(Color.vendaWhite)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    Spacer()
                    Text("Analytics")
                        .font(.system(size: 18, weight: .semibold, design: .default))
                        .foregroundColor(.vendaInk)
                    Spacer()
                    // Dummy spacer for balance
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 40, height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // Timeframe Picker
                        Picker("", selection: $selectedTimeframe) {
                            Text("This Week").tag(0)
                            Text("This Month").tag(1)
                            Text("This Year").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        
                        // Summary Card
                        VendaCard(backgroundColor: .vendaForestDk) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Total Revenue")
                                    .font(.system(size: 13, weight: .medium, design: .default))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("K 15,350.00")
                                    .font(.system(size: 32, weight: .bold, design: .default))
                                    .foregroundColor(.white)
                                
                                HStack {
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("+18.4% vs last week")
                                        .font(.system(size: 11, weight: .medium, design: .default))
                                }
                                .foregroundColor(.vendaOchre)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // Chart Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Sales Volume")
                                .font(.system(size: 15, weight: .semibold, design: .default))
                                .foregroundColor(.vendaInk)
                                .padding(.horizontal, 16)
                                
                            // Geometry Chart
                            VendaCard {
                                GeometryReader { geometry in
                                    HStack(alignment: .bottom, spacing: 0) {
                                        let maxDouble = Double(truncating: maxValue as NSNumber)
                                        ForEach(weeklyData) { dataPoint in
                                            let valDouble = Double(truncating: dataPoint.value as NSNumber)
                                            let ratio = maxDouble > 0 ? valDouble / maxDouble : 0
                                            let barHeight = CGFloat(ratio) * geometry.size.height
                                            let isMax = dataPoint.value == maxValue
                                            
                                            VStack(spacing: 8) {
                                                Spacer()
                                                
                                                if isMax {
                                                    Text(dataPoint.value.asZMW())
                                                        .font(.system(size: 9, weight: .bold, design: .default))
                                                        .foregroundColor(.vendaInkMid)
                                                        .lineLimit(1)
                                                        .minimumScaleFactor(0.8)
                                                        .padding(.horizontal, 2)
                                                }
                                                
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(isMax ? Color.vendaForest : Color.vendaForestLt)
                                                    .frame(height: max(barHeight, 8)) // Ensure minimum height
                                                    .padding(.horizontal, 4)
                                                
                                                Text(dataPoint.label)
                                                    .font(.system(size: 11, weight: .medium, design: .default))
                                                    .foregroundColor(.vendaInkLt)
                                            }
                                            .frame(width: geometry.size.width / CGFloat(weeklyData.count))
                                        }
                                    }
                                }
                                .frame(height: 200)
                                .padding(.top, 12)
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // Top Products
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Top Performers")
                                    .font(.system(size: 15, weight: .semibold, design: .default))
                                    .foregroundColor(.vendaInk)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            
                            VStack(spacing: 8) {
                                TopProductRow(name: "Premium Braids", sales: 42, revenue: 8400)
                                TopProductRow(name: "Latte Macchiato", sales: 128, revenue: 3200)
                                TopProductRow(name: "Consultation", sales: 12, revenue: 1800)
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        Spacer().frame(height: 40)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Decimal
}

private struct TopProductRow: View {
    let name: String
    let sales: Int
    let revenue: Decimal
    
    var body: some View {
        VendaCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundColor(.vendaInk)
                    Text("\(sales) sold")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(.vendaInkMid)
                }
                Spacer()
                Text(revenue.asZMW())
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundColor(.vendaForest)
            }
        }
    }
}

#Preview {
    ReportsScreen()
}
