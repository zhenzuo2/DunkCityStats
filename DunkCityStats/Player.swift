import Foundation
import SwiftUI

struct Player: Identifiable {
    var id: String { name }
    let name: String
    let position: String
    
    // Core Stats
    let dunk: Int
    let layupClose: Int
    let midRange: Int
    let threePoint: Int
    let dribble: Int
    let steal: Int
    let block: Int
    let rebound: Int
    let contest: Int
    let pass: Int
    let vertical: Int
    let movement: Int
    let consistency: Int
    let strength: Int
    
    // Derived/Overall Stats are calculated from core attributes.
    var total: Int { totalScore() }
    var avgAttribute: Double { averageAttributeScore() }
    var offense: Int { offenseScore() }
    var defense: Int { defenseScore() }
    var athleticism: Int { athleticismScore() }
}

struct RadarMetric: Identifiable {
    let id: String
    let nameKey: String
    let keyPath: KeyPath<Player, Int>

    init(_ nameKey: String, _ keyPath: KeyPath<Player, Int>) {
        self.id = nameKey
        self.nameKey = nameKey
        self.keyPath = keyPath
    }
}

extension Player {
    private var coreAttributes: [Int] {
        [
            dunk, layupClose, midRange, threePoint, dribble, steal, block,
            rebound, contest, pass, vertical, movement, consistency, strength
        ]
    }

    func totalScore() -> Int {
        coreAttributes.reduce(0, +)
    }

    func averageAttributeScore() -> Double {
        guard !coreAttributes.isEmpty else { return 0 }
        return Double(totalScore()) / Double(coreAttributes.count)
    }

    func offenseScore() -> Int {
        dunk + layupClose + midRange + threePoint + dribble + pass
    }

    func defenseScore() -> Int {
        steal + block + rebound + contest + consistency
    }

    func athleticismScore() -> Int {
        vertical + movement + strength
    }

    static let radarMetrics: [RadarMetric] = [
        RadarMetric("stat.short.dunk", \.dunk),
        RadarMetric("stat.short.layup", \.layupClose),
        RadarMetric("stat.short.mid", \.midRange),
        RadarMetric("stat.short.three_pt", \.threePoint),
        RadarMetric("stat.short.dribble", \.dribble),
        RadarMetric("stat.short.steal", \.steal),
        RadarMetric("stat.short.block", \.block),
        RadarMetric("stat.short.rebound", \.rebound),
        RadarMetric("stat.short.contest", \.contest),
        RadarMetric("stat.short.pass", \.pass),
        RadarMetric("stat.short.vertical", \.vertical),
        RadarMetric("stat.short.movement", \.movement),
        RadarMetric("stat.short.consistency", \.consistency),
        RadarMetric("stat.short.strength", \.strength)
    ]

    var detailedStats: [(nameKey: String, value: Int)] {
        [
            ("stat.full.dunk", dunk),
            ("stat.full.layup_close", layupClose),
            ("stat.full.mid_range", midRange),
            ("stat.full.three_pt", threePoint),
            ("stat.full.dribble", dribble),
            ("stat.full.steal", steal),
            ("stat.full.block", block),
            ("stat.full.rebound", rebound),
            ("stat.full.contest", contest),
            ("stat.full.pass", pass),
            ("stat.full.vertical", vertical),
            ("stat.full.movement", movement),
            ("stat.full.consistency", consistency),
            ("stat.full.strength", strength),
            ("stat.full.offense", offense),
            ("stat.full.defense", defense),
            ("stat.full.athleticism", athleticism),
            ("stat.full.total", total)
        ]
    }

    var headshotURL: URL? {
        guard let urlString = Self.headshotURLByName[Self.normalizedName(name)] else {
            return nil
        }
        return URL(string: urlString)
    }

    private static func normalizedName(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }

    private static let headshotURLByName: [String: String] = {
        let base = "https://www.dunkcitymobile.com/pc/gw/20240712205108/assets/"
        return [
            normalizedName("Curry"): base + "card-kl_f2ecaf22.png",
            normalizedName("Irving"): base + "ouwen-big_569ad7ef.png",
            normalizedName("S.G.Alexander"): base + "card-sga_907e599b.png",
            normalizedName("Kidd"): base + "card-jkidd_53fa06b7.png",
            normalizedName("Lin"): base + "lsh-big_d9d2fc0b.png",
            normalizedName("Paul"): base + "card-bl_95cdc52d.png",
            normalizedName("Doncic"): base + "card-dqq_31a6de27.png",
            normalizedName("Westbrook"): base + "card-wsblk_5103594a.png",
            normalizedName("Zhou Chang"): base + "card-zc_277526f0.png",
            normalizedName("Murrary"): base + "card-ml_141eed8a.png",
            normalizedName("Murray"): base + "card-ml_141eed8a.png",
            normalizedName("Hong Shou"): base + "card-hs_f022955c.png",
            normalizedName("Wade"): base + "card-wade_8d8cf0c2.png",
            normalizedName("Harden"): base + "card-harden_c654da94.png",
            normalizedName("Allen"): base + "card-RayAllen_b3380af3.png",
            normalizedName("Clarkson"): base + "card-klks_07ec9afc.png",
            normalizedName("Thompson"): base + "card-tps_ae67d822.png",
            normalizedName("McCollum"): base + "card-mcCollum_4bbecd25.png",
            normalizedName("Lavine"): base + "card-laVine_9356e93c.png",
            normalizedName("Booker"): base + "card-bk_4876f4b7.png",
            normalizedName("Crawford"): base + "card-klfd_3d197050.png",
            normalizedName("Schroder"): base + "card-sld_ac749746.png",
            normalizedName("Seth Curry"): base + "card-sskl_588020f1.png",
            normalizedName("James16"): base + "card-james_d5f34bc3.png",
            normalizedName("Leonard"): base + "card-kawhi_35de2e8e.png",
            normalizedName("Durant"): base + "card-dlt_ce55f1ec.png",
            normalizedName("Butler"): base + "card-butler_8ccd6219.png",
            normalizedName("Brown"): base + "card-brown_b0823d5a.png",
            normalizedName("Wiggins"): base + "card-wjs_fbafc3cd.png",
            normalizedName("Fu Zhi"): base + "card-fz_1fc45141.png",
            normalizedName("Ingram"): base + "card-yglm_80dc0c1c.png",
            normalizedName("Brooks"): base + "card-brooks_d716255b.png",
            normalizedName("George"): base + "card-blqz_a1c8ceac.png",
            normalizedName("Derozan"): base + "card-dlz_9129ac30.png",
            normalizedName("Hayward"): base + "card-hwd_7dea6849.png",
            normalizedName("Peterson"): base + "card-pts_1014ec81.png",
            normalizedName("Johnson"): base + "card-kmlyhx_e229cc18.png",
            normalizedName("Tatum"): base + "card-ttm_e062a4eb.png",
            normalizedName("Tatum (Perimeter)"): base + "card-ttm_e062a4eb.png",
            normalizedName("Tatum (Interior)"): base + "card-ttm_e062a4eb.png",
            normalizedName("Malone"): base + "card-malone_053cf787.png",
            normalizedName("Antetokounmpo"): base + "card-yns_288b4a26.png",
            normalizedName("Rodman"): base + "card-rodman_6a0bef31.png",
            normalizedName("Nowitzki"): base + "card-nvsj_b169d5df.png",
            normalizedName("Jackson Jr."): base + "card-jaren_1c08a61b.png",
            normalizedName("Anderson"): base + "card-lke_a1de904a.png",
            normalizedName("Siakam"): base + "card-PascaSiakam_e6ca07d3.png",
            normalizedName("Gordon"): base + "card-gordon_7ea8ecf2.png",
            normalizedName("Julio"): base + "card-hla_062ac2d4.png",
            normalizedName("Williamson"): base + "card-xa_324e3f97.png",
            normalizedName("Kuminga"): base + "card-kjm_e2b79deb.png",
            normalizedName("McDyess"): base + "card-mkds_283ca8a5.png",
            normalizedName("Olajuwon"): base + "card-hakeem_dc6940c6.png",
            normalizedName("Jokic"): base + "card-yjq_ee094a0e.png",
            normalizedName("Embiid"): base + "card-ebd_aa153eca.png",
            normalizedName("Gasol"): base + "card-djse_f235fa08.png",
            normalizedName("Wallace"): base + "card-wallace_47db1773.png",
            normalizedName("Davis"): base + "card-davis_1bd3026a.png",
            normalizedName("Lopez"): base + "card-lopez_5c49a151.png",
            normalizedName("Porzingis"): base + "card-bejjs_d293068c.png",
            normalizedName("Adebayo"): base + "card-bm_e272b2a8.png",
            normalizedName("Capela"): base + "card-kpl_4b11bd82.png",
            normalizedName("Nurkic"): base + "card-nejq_df066f95.png",
            normalizedName("Adams"): base + "card-yds_d60c162d.png",
            normalizedName("Miller"): base + "card-bldml_71bfe114.png",
            normalizedName("James"): base + "card-zms_c6c5f3ad.png"
        ]
    }()
}

struct PlayerHeadshotView: View {
    let player: Player
    var size: CGFloat = 48
    var cornerRadius: CGFloat = 10

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.gray.opacity(0.12))

            if let url = player.headshotURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var placeholder: some View {
        Image(systemName: "person.fill")
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}
