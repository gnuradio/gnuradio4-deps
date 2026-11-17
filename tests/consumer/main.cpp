#include <boost/ut.hpp>
#include <httplib.h>
#include <magic_enum.hpp>
#include <vir/simd.h>

#ifdef CHECK_BLOCKS
#include <SoapySDR/Version.hpp>
#endif
#ifdef CHECK_CONTROL_PLANE
#include <boost/asio/io_context.hpp>
#include <boost/beast/http/verb.hpp>
#include <nlohmann/json.hpp>
#include <zlib.h>
#endif
#ifdef CHECK_STUDIO
#include <openssl/sha.h>
#endif

#include <string>

enum class Status { ready };

int main() {
    using namespace boost::ut;
    "installed dependencies"_test = [] {
        expect(magic_enum::enum_name(Status::ready) == "ready");
        const vir::stdx::native_simd<float> lanes(1.f);
        expect(lanes[0] == 1.f);
        httplib::Headers headers;
        headers.emplace("Accept", "text/plain");
        expect(headers.count("Accept") == 1u);
#ifdef CHECK_BLOCKS
        expect(!SoapySDR::getLibVersion().empty());
#endif
#ifdef CHECK_CONTROL_PLANE
        const nlohmann::json value = {{"answer", 42}};
        expect(value.at("answer").get<int>() == 42);
        boost::asio::io_context context;
        expect(context.poll() == 0u);
        expect(boost::beast::http::to_string(boost::beast::http::verb::get) == "GET");
        const char input[] = "dependency smoke test";
        unsigned char compressed[128];
        uLongf size = sizeof(compressed);
        expect(compress(compressed, &size, reinterpret_cast<const Bytef*>(input), sizeof(input)) == Z_OK);
#endif
#ifdef CHECK_STUDIO
        const unsigned char sha_input[] = "abc";
        unsigned char digest[SHA_DIGEST_LENGTH];
        expect(SHA1(sha_input, 3, digest) == digest);
        expect(digest[0] == 0xa9u);
        expect(digest[SHA_DIGEST_LENGTH - 1] == 0x9du);
#endif
    };
}
