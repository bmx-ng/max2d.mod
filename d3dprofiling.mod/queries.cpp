// Native query calls only; queue ownership and sample accounting live in BlitzMax.
#include <windows.h>
#include <d3d9.h>
#include <d3d11.h>
#include <stdint.h>
#include <new>
struct TimerSlot {
 IDirect3DQuery9 *a9=0,*b9=0,*dis9=0,*freq9=0;
 ID3D11Query *a11=0,*b11=0,*dis11=0;
 ~TimerSlot() {
  if(a9)a9->Release(); if(b9)b9->Release(); if(dis9)dis9->Release(); if(freq9)freq9->Release();
  if(a11)a11->Release(); if(b11)b11->Release(); if(dis11)dis11->Release();
 }
};
struct TimerQueries {
 TimerSlot *slots=0;
 ID3D11DeviceContext *context=0;
 ~TimerQueries(){delete[] slots;if(context)context->Release();}
};
extern "C" {
void m2d_timer_free(TimerQueries *t){delete t;}
TimerQueries *m2d_timer_create9(IDirect3DDevice9 *device,int capacity){
 TimerQueries *t=new(std::nothrow) TimerQueries;
 if(!t)return 0;
 t->slots=new(std::nothrow) TimerSlot[capacity];
 if(!t->slots){delete t;return 0;}
 for(int i=0;i<capacity;++i){
  TimerSlot &s=t->slots[i];
  if(FAILED(device->CreateQuery(D3DQUERYTYPE_TIMESTAMP,&s.a9)) ||
     FAILED(device->CreateQuery(D3DQUERYTYPE_TIMESTAMP,&s.b9)) ||
     FAILED(device->CreateQuery(D3DQUERYTYPE_TIMESTAMPDISJOINT,&s.dis9)) ||
     FAILED(device->CreateQuery(D3DQUERYTYPE_TIMESTAMPFREQ,&s.freq9))){delete t;return 0;}
 }
 return t;
}
TimerQueries *m2d_timer_create11(ID3D11Device *device,ID3D11DeviceContext *context,int capacity){
 TimerQueries *t=new(std::nothrow) TimerQueries;
 if(!t)return 0;
 t->context=context;context->AddRef();
 t->slots=new(std::nothrow) TimerSlot[capacity];
 if(!t->slots){delete t;return 0;}
 for(int i=0;i<capacity;++i){
  TimerSlot &s=t->slots[i];D3D11_QUERY_DESC desc={D3D11_QUERY_TIMESTAMP,0};
  if(FAILED(device->CreateQuery(&desc,&s.a11)) || FAILED(device->CreateQuery(&desc,&s.b11))){delete t;return 0;}
  desc.Query=D3D11_QUERY_TIMESTAMP_DISJOINT;
  if(FAILED(device->CreateQuery(&desc,&s.dis11))){delete t;return 0;}
 }
 return t;
}
int m2d_timer_begin(TimerQueries *t,int index){
 TimerSlot &s=t->slots[index];
 if(t->context){t->context->Begin(s.dis11);t->context->End(s.a11);return 1;}
 if(FAILED(s.dis9->Issue(D3DISSUE_BEGIN)))return 0;
 if(FAILED(s.a9->Issue(D3DISSUE_END))){s.dis9->Issue(D3DISSUE_END);return 0;}
 return 1;
}
int m2d_timer_end(TimerQueries *t,int index){
 TimerSlot &s=t->slots[index];
 if(t->context){t->context->End(s.b11);t->context->End(s.dis11);t->context->Flush();return 1;}
 HRESULT b=s.b9->Issue(D3DISSUE_END),d=s.dis9->Issue(D3DISSUE_END),f=s.freq9->Issue(D3DISSUE_END);
 // Submit once; polling below never flushes or waits.
 HRESULT submit=s.freq9->GetData(0,0,D3DGETDATA_FLUSH);
 return SUCCEEDED(b)&&SUCCEEDED(d)&&SUCCEEDED(f)&&SUCCEEDED(submit);
}
// 0 pending, 1 valid, -1 completed but unreliable, -2 native failure.
int m2d_timer_poll(TimerQueries *t,int index,int64_t *nanos){
 TimerSlot &s=t->slots[index];UINT64 a=0,b=0,freq=0;BOOL disjoint=FALSE;
 HRESULT ra,rb,rd,rf=S_OK;
 if(t->context){
  D3D11_QUERY_DATA_TIMESTAMP_DISJOINT data={};
  rd=t->context->GetData(s.dis11,&data,sizeof(data),D3D11_ASYNC_GETDATA_DONOTFLUSH);
  ra=t->context->GetData(s.a11,&a,sizeof(a),D3D11_ASYNC_GETDATA_DONOTFLUSH);
  rb=t->context->GetData(s.b11,&b,sizeof(b),D3D11_ASYNC_GETDATA_DONOTFLUSH);
  freq=data.Frequency;disjoint=data.Disjoint;
 }else{
  rd=s.dis9->GetData(&disjoint,sizeof(disjoint),0);rf=s.freq9->GetData(&freq,sizeof(freq),0);
  ra=s.a9->GetData(&a,sizeof(a),0);rb=s.b9->GetData(&b,sizeof(b),0);
 }
 if(FAILED(ra)||FAILED(rb)||FAILED(rd)||FAILED(rf))return -2;
 if(ra!=S_OK||rb!=S_OK||rd!=S_OK||rf!=S_OK)return 0;
 if(disjoint||!freq||b<a)return -1;
 const long double elapsed=static_cast<long double>(b-a)*1000000000.0L/freq;
 if(elapsed>=9223372036854775807.0L)return -1;
 *nanos=static_cast<int64_t>(elapsed);return 1;
}
}
