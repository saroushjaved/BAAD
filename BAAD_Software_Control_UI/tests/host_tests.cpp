#include "burst_transfer.h"
#include "protocol_codec.h"
#include "session_recorder.h"
#include "dds_math.h"
#include <QCoreApplication>
#include <QTemporaryDir>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <cstdio>
#include <cstdlib>
#include <cstring>
static int checks=0;
#define CHECK(x) do { ++checks; if(!(x)){ std::fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#x);std::exit(1);} } while(0)
static void put(QByteArray &b,int index,quint64 value){for(int k=0;k<8;++k)b[index*8+k]=char(value>>(8*k));}
static quint32 crc(const QByteArray &b){return baad_crc32(reinterpret_cast<const uint8_t*>(b.constData()),b.size());}
static QByteArray fixture(int n,int source,int flags=0,bool gap=false){
 QByteArray b((n+10)*8,'\0');int stride=source?4:1;
 put(b,0,(quint64(0xbaad0204u)<<32)|(quint64(n+10)<<16)|flags);
 put(b,1,(quint64(7)<<32)|n);put(b,2,100000);put(b,3,100000+(n-1)*stride+(gap?1:0));
 put(b,4,(quint64(BAAD_SYSTEM_SAMPLE_RATE_HZ)<<32)|(4u<<16)|(6u<<8)|source);
 put(b,5,quint64(42)<<32);put(b,6,0x0000000100000008ull);
 for(int j=0;j<n;++j)put(b,8+j,(quint64(j*stride+(gap&&j>=100?1:0))<<32)|(quint64(quint16(-500))<<16)|quint16(j-100));
 put(b,n+8,(quint64(0x454e4421)<<32)|(quint64(n)<<16)|flags);
 put(b,n+9,(quint64(0x43524332)<<32)|crc(b.first(b.size()-8)));return b;
}
static QByteArray ready(const QByteArray &b,int flags=0){BaadCaptureReady r={7,quint32(b.size()),crc(b),quint32(flags)};return QByteArray(reinterpret_cast<char*>(&r),sizeof(r));}
static QByteArray chunk(const QByteArray &b,const QByteArray &req){
 BaadReadCapture r={};memcpy(&r,req.constData(),sizeof(r));
 BaadCaptureChunk c={};c.capture_id=r.capture_id;c.offset=r.offset;c.length=r.length;
 memcpy(c.data,b.constData()+r.offset,r.length);return QByteArray(reinterpret_cast<char*>(&c),12+r.length);
}
int main(int argc,char **argv){QCoreApplication app(argc,argv);
 CHECK(crc("123456789")==0xcbf43926);
 for(int split=0;split<530;++split){
  const QByteArray p(512,'x');const auto frame=ProtocolCodec::encode(0x86,65535,p);ProtocolCodec codec;
  auto a=codec.feed(frame.first(qMin(split,int(frame.size()))));
  a+=codec.feed(frame.mid(qMin(split,int(frame.size()))));CHECK(a.size()==1);CHECK(a[0].sequence==65535&&a[0].payload==p);
 }
 ProtocolCodec codec;auto frame=ProtocolCodec::encode(0x82,0,"hello");auto bad=frame;bad[9]^=1;
 auto frames=codec.feed("garbage"+bad+frame+frame);CHECK(frames.size()==2);CHECK(codec.errors()>0);
 CHECK(ProtocolCodec::encode(1,0,QByteArray(513,'x')).isEmpty());
 for(int source=0;source<2;++source)for(int count:{256,8192})for(int flags:{0,1}){
  const auto b=fixture(count,source,flags);const auto record=BurstRecord::decode(b);
  CHECK(record.integrityValid);CHECK(record.scienceValid==(flags==0));CHECK(record.samples.size()==count);
  CHECK(record.samples[0].i==-100&&record.samples[0].q==-500);
  BurstTransfer t;QString error;CHECK(t.begin(ready(b,flags),&error));CHECK(t.begin(ready(b,flags),&error));
  while(!t.complete()){
   auto c=chunk(b,t.nextRequest());const auto r=t.accept(c,&error);CHECK(r==BurstTransfer::More||r==BurstTransfer::Complete);
   CHECK(t.accept(c,&error)==BurstTransfer::Duplicate);
  }
  CHECK(t.bytes()==b);CHECK(t.nextRequest().isEmpty());CHECK(t.record().scienceValid==(flags==0));
 }
 const auto b=fixture(256,1);QString error;BurstTransfer t;CHECK(t.begin(ready(b),&error));
 auto c=chunk(b,t.nextRequest());auto wrong=c;wrong[0]^=1;CHECK(t.accept(wrong,&error)==BurstTransfer::Error);
 CHECK(t.accept(c,&error)==BurstTransfer::More);wrong=c;wrong[15]^=1;CHECK(t.accept(wrong,&error)==BurstTransfer::Error);
 auto corrupt=b;corrupt[70]^=1;CHECK(!BurstRecord::decode(corrupt).integrityValid);
 CHECK(!BurstRecord::decode(b.first(b.size()-1)).integrityValid);
 CHECK(!BurstRecord::decode(fixture(256,1,0,true)).scienceValid);
 auto wrongReady=ready(b);wrongReady[8]^=1;t.reset();CHECK(t.begin(wrongReady,&error));
 while(!t.complete()){const auto r=t.accept(chunk(b,t.nextRequest()),&error);if(t.complete())CHECK(r==BurstTransfer::Error);else CHECK(r==BurstTransfer::More);}
 QTemporaryDir temp;CHECK(temp.isValid());SessionRecorder s;CHECK(s.start(temp.path(),{{"test_data",true}}));
 const QString dir=s.directory();CHECK(s.raw(frame,false));CHECK(s.raw(frame,true));CHECK(s.event("test"));
 CHECK(s.capture(b,BurstRecord::decode(b)));CHECK(s.capture(b.first(40),{},"interrupted"));CHECK(s.testRun("fabricated",{}));
 s.close();QFile manifest(dir+"/manifest.json");CHECK(manifest.open(QIODevice::ReadOnly));
 CHECK(QJsonDocument::fromJson(manifest.readAll()).object()["status"]=="closed");
 CHECK(QDir(dir).entryList({"*.bin"},QDir::Files).size()==4);
 QFile obstruction(temp.path()+"/file");CHECK(obstruction.open(QIODevice::WriteOnly));obstruction.close();
 CHECK(!s.start(obstruction.fileName(),{}));CHECK(!s.error().isEmpty());
 for(double bw:{2e6,4e6,8e6,16e6,20e6}){auto tones=DdsMath::makeTones(bw,10000000,62000000);CHECK(tones.size()==6);CHECK(DdsMath::tonesInRange(tones,62000000,&error));}
 std::printf("PASS %d host checks: protocol fragmentation/CRC, burst bounds/retries/integrity/cadence, recording/failures, DDS presets\n",checks);
}
