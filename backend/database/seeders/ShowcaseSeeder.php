<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Company;
use App\Models\Drama;
use App\Models\Tag;
use App\Services\BunnyStream;
use App\Support\CatalogCache;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Afriva Originals showcase catalogue: 16 dramas with real posters (public/showcase) whose episodes all play one
 * shared sample video. Safe to re-run (upserts dramas, rebuilds their episodes and recent view activity).
 *
 * Video: BUNNY_STREAM_SHOWCASE_VIDEO=<bunny guid>; also list it in BUNNY_STREAM_PROTECTED_VIDEOS so deleting a demo
 * episode never removes it.
 */
class ShowcaseSeeder extends Seeder
{
    public const COMPANY_SLUG = 'afriva-originals';

    /** [slug, title, categories, tags, badge, featured, episodes, synopsis] */
    public static function catalogue(): array
    {
        return [
            ['a-men', 'A-Men: Shujaa wa Tanzania', ['Action', 'Thriller'], ['Superhero', 'Dar es Salaam', 'Strong Hero'], 'hot', true, 60,
                'Mlinzi wa usiku wa bandari ya Dar es Salaam anapata nguvu za ajabu baada ya radi kumpiga juu ya jengo refu. Sasa kundi la siri linamtaka ajiunge nao kabla maadui wa jiji hawajamgundua.'],
            ['coin-ya-bakhresa', 'Coin ya Bakhresa: Sarafu ya Siri', ['Thriller', 'Billionaire'], ['Mystery', 'Treasure', 'Business'], 'vip', true, 48,
                'Sarafu ya dhahabu ya zamani inapatikana ndani ya sefu ya tajiri mkubwa wa Dar. Kila mtu aliyeigusa amepotea. Mpelelezi mmoja ana siku saba kufichua siri yake.'],
            ['hawakujua-ni-billionea', 'Hawakujua ni Billionea: Siri ya Tajiri', ['Billionaire', 'Family'], ['Secret Identity', 'Rich and Poor', 'Dar es Salaam'], 'hot', true, 72,
                'Kijana anayeuza matunda Kariakoo anadharauliwa na kila mtu sokoni. Siku moja magari ya kifahari yanasimama mbele ya kibanda chake, na ukweli kuhusu yeye unaanza kujulikana.'],
            ['kinjekitile-ngwale', 'Kinjekitile Ngwale: Mtu wa Maji', ['Historical'], ['Maji Maji', 'True Story', 'Legend'], 'new', true, 40,
                'Mwaka 1904, mganga wa Ngarambe anadai kuwa na maji yanayogeuza risasi za Wajerumani kuwa maji. Imani yake inawaunganisha watu wa kusini kuanzisha vita kubwa ya ukombozi.'],
            ['maji-maji-war', 'Maji Maji: War', ['Historical', 'Action'], ['Maji Maji', 'War', 'True Story'], 'hot', false, 56,
                'Mashamba ya pamba yanawaka moto. Shujaa mmoja wa Kimatumbi anaongoza wenzake kwa mikuki na imani dhidi ya bunduki za wakoloni katika vita iliyobadilisha historia ya Tanganyika.'],
            ['mali-za-ajabu', 'Mali za Ajabu: Hazina Iliyolaaniwa', ['Adventure', 'Thriller'], ['Treasure', 'Curse', 'Jungle'], 'new', false, 36,
                'Ramani ya zamani inawaongoza marafiki watatu ndani ya msitu mnene hadi kwenye sanduku la hazina. Lakini kila kitu wanachochukua kinaleta laana mpya.'],
            ['mangi-meli', 'Mangi Meli: Mti wa Kunyongwa', ['Historical'], ['Kilimanjaro', 'Chagga', 'True Story'], null, false, 44,
                'Mtawala jasiri wa Wachagga wa Moshi anakataa kuinama mbele ya Wajerumani. Hadithi ya ujasiri wake na mti wa kihistoria chini ya mlima Kilimanjaro.'],
            ['manyau-nyau', 'Manyau Nyau: Mwindaji wa Wachawi', ['Horror', 'Village Life'], ['Supernatural', 'Folklore', 'Witch Hunter'], 'hot', false, 50,
                'Kila usiku wa mwezi mpevu watoto wanapotea kijijini. Mwindaji wa wachawi mwenye taa ya ajabu anarudi kijijini, lakini wanakijiji hawajui kama yeye ni mkombozi au tishio jipya.'],
            ['marebo', 'Marebo: Jambazi wa Kutisha', ['Action', 'Thriller'], ['Crime', 'Manhunt', 'Outlaw'], null, false, 42,
                'Jambazi anayeogopwa kuliko wote milimani anawindwa na askari wa kikoloni. Kwa wanakijiji yeye ni shujaa; kwa serikali ni adui namba moja.'],
            ['masai-warrior', 'Masai Warrior: Shujaa wa Kabila', ['Action', 'Village Life'], ['Maasai', 'Coming of Age', 'Strong Hero'], 'vip', true, 64,
                'Kijana wa Kimaasai anapaswa kuthibitisha ujasiri wake ili aongoze ng\'ombe wa kabila lake kupitia nyika ya hatari chini ya mlima Kilimanjaro.'],
            ['mirambo', 'Mirambo: Mfalme wa Vita', ['Historical', 'Action'], ['Nyamwezi', 'King', 'True Story'], 'hot', true, 70,
                'Kutoka kijana wa kawaida hadi mfalme wa Wanyamwezi aliyeogopwa na misafara yote ya Tabora. Safari ya Mirambo, mwanamkakati wa vita aliyejenga dola kubwa.'],
            ['msuguli', 'Msuguli: Askari wa Heshima', ['Historical', 'Thriller'], ['Detective', 'Dar es Salaam', 'Colonial Era'], null, false, 38,
                'Mwili unapatikana bandarini Dar es Salaam ya zamani. Askari mwaminifu anapambana na rushwa ya wakubwa wake ili kuleta haki kwa watu wake.'],
            ['muku', 'Muku: Siri ya Mtu wa Ajabu', ['Thriller', 'Village Life'], ['Mystery', 'Stranger', 'Folklore'], 'new', false, 32,
                'Mgeni mwenye kilemba anafika kijijini usiku mmoja na kila kitu kinaanza kubadilika. Nani yeye, na kwa nini wazee wanaogopa kutaja jina lake?'],
            ['mwana-malundi', 'Mwana Malundi: Siri ya Mwanza', ['Thriller', 'Family'], ['Lake Victoria', 'Legend', 'Mystery'], null, false, 46,
                'Mvuvi wa Ziwa Victoria anarithi siri ya babu yake, Mwana Malundi, mtu aliyesemekana kutoweka na kurudi kama upepo. Mwanza nzima inamtazama.'],
            ['popobawa', 'Popobawa: Usiku wa Hofu', ['Horror'], ['Supernatural', 'Zanzibar', 'Folklore'], 'hot', true, 52,
                'Usiku Mji Mkongwe wa Zanzibar, kiumbe chenye mabawa kinashambulia nyumba moja baada ya nyingine. Mvuvi mmoja anaamua kukabiliana nacho kabla hakijamchukua mwanawe.'],
            ['zinjathropas', 'Zinjathropas: Fuvu la Mababu', ['Adventure', 'Historical'], ['Olduvai', 'Science', 'Ancestors'], 'new', false, 30,
                'Mtafiti kijana kwenye bonde la Olduvai anagundua fuvu la mababu wa kale. Ugunduzi wake unaamsha siri za mamilioni ya miaka, na watu wanaotaka kuiba historia.'],
        ];
    }

    public function run(): void
    {
        $videoUrl = $this->videoUrl();
        $base = rtrim((string) config('app.url'), '/').'/showcase';
        $now = now();
        mt_srand(20261031);

        $company = Company::updateOrCreate(['slug' => self::COMPANY_SLUG], [
            'name' => 'Afriva Originals',
            'email' => 'originals@afriva.co.tz',
            'country' => 'TZ',
            'revenue_share_percent' => 0,
            'status' => 'active',
            'description' => 'Tamthilia asili za Afriva, zilizotengenezwa Tanzania.',
        ]);

        $nextOrder = (int) Category::max('sort_order');
        foreach (['Action', 'Adventure', 'Horror', 'Historical', 'Thriller', 'Billionaire', 'Family', 'Village Life'] as $name) {
            $slug = Str::slug($name);
            if (! Category::where('slug', $slug)->exists()) {
                Category::create(['name' => $name, 'slug' => $slug, 'sort_order' => ++$nextOrder]);
            }
        }
        // Showcase genres first on the home page.
        foreach (['historical', 'action', 'thriller', 'horror', 'adventure', 'billionaire', 'family', 'village-life'] as $i => $slug) {
            Category::where('slug', $slug)->update(['sort_order' => $i + 1]);
        }
        $categories = Category::pluck('id', 'name');

        $viewRows = [];
        foreach (self::catalogue() as $i => [$slug, $title, $cats, $tags, $badge, $featured, $epCount, $synopsis]) {
            $views = match ($badge) {
                'hot' => mt_rand(1_200_000, 3_800_000),
                'vip' => mt_rand(700_000, 1_900_000),
                'new' => mt_rand(90_000, 600_000),
                default => mt_rand(150_000, 900_000),
            };
            $release = $badge === 'new' ? $now->copy()->subDays(mt_rand(2, 30)) : $now->copy()->subDays(mt_rand(45, 300));

            $drama = Drama::updateOrCreate(['slug' => $slug], [
                'company_id' => $company->id,
                'title' => $title,
                'synopsis' => $synopsis,
                'poster_url' => "{$base}/{$slug}.webp",
                'backdrop_url' => "{$base}/{$slug}-wide.webp",
                'total_episodes' => $epCount,
                'free_episodes' => 5,
                'coins_per_episode' => 30,
                'status' => 'published',
                'is_featured' => $featured,
                'badge' => $badge,
                'language' => 'sw',
                'release_date' => $release->toDateString(),
                'views' => $views,
            ]);
            $drama->categories()->sync(array_map(fn ($c) => $categories[$c], $cats));
            $drama->tags()->sync(Tag::idsFor($tags));

            DB::table('episode_views')->where('drama_id', $drama->id)->delete();
            DB::table('episodes')->where('drama_id', $drama->id)->delete();
            $episodes = [];
            for ($n = 1; $n <= $epCount; $n++) {
                $episodes[] = [
                    'drama_id' => $drama->id,
                    'number' => $n,
                    'title' => null,
                    'video_url' => $videoUrl,
                    'video_status' => 'ready',
                    'thumbnail_url' => "{$base}/{$slug}.webp",
                    'duration_seconds' => mt_rand(80, 180),
                    'is_free' => null,
                    'views' => (int) round($views * 0.18 * pow(0.955, $n - 1)),
                    'created_at' => $release,
                    'updated_at' => $release,
                ];
            }
            DB::table('episodes')->insert($episodes);

            // A week of viewing activity so "Trending" has a ranking (hot titles watched most).
            $firstEpisode = DB::table('episodes')->where('drama_id', $drama->id)->where('number', 1)->value('id');
            $daily = match ($badge) {
                'hot' => mt_rand(30, 60), 'vip' => mt_rand(18, 35), 'new' => mt_rand(12, 28), default => mt_rand(4, 15)
            };
            for ($d = 0; $d < 7; $d++) {
                $day = $now->copy()->subDays($d);
                for ($k = 0; $k < $daily; $k++) {
                    $viewRows[] = ['episode_id' => $firstEpisode, 'drama_id' => $drama->id, 'company_id' => $company->id,
                        'user_id' => null, 'viewed_on' => $day->toDateString(), 'created_at' => $day, 'updated_at' => $day];
                }
            }
        }
        foreach (array_chunk($viewRows, 500) as $chunk) {
            DB::table('episode_views')->insert($chunk);
        }

        CatalogCache::flush();
    }

    protected function videoUrl(): string
    {
        $guid = config('services.bunny.showcase_video');
        if ($guid && config('services.bunny.cdn_hostname')) {
            return app(BunnyStream::class)->playlistUrl($guid);
        }

        throw new \RuntimeException('Set BUNNY_STREAM_SHOWCASE_VIDEO (the shared Bunny video id) before running ShowcaseSeeder.');
    }
}
